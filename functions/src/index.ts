// @ts-nocheck
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import { ImageAnnotatorClient } from "@google-cloud/vision";

admin.initializeApp();

const client = new ImageAnnotatorClient();

/**
 * Cloud Function to process whiteboard images.
 * Expects { imagePath: 'path/to/image.jpg' } in data.
 * Returns { tasks: [ { title: '...', bucket: '...' } ] }
 */
exports.processWhiteboardImage = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The function must be called while authenticated."
        );
    }

    const imagePath = data.imagePath;
    if (!imagePath) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "The function must be called with a valid imagePath."
        );
    }

    try {
        // 1. Get the image from Storage
        const bucket = admin.storage().bucket();
        const gcsUri = `gs://${bucket.name}/${imagePath}`;

        console.log(`Analyzing image at: ${gcsUri}`);

        // 2. Call Vision API
        const [result] = await client.textDetection(gcsUri);
        const detections = result.textAnnotations;

        if (!detections || detections.length === 0) {
            return { tasks: [] };
        }

        // 3. Parse detections into tasks
        const tasks = parseDetections(detections);

        return { tasks: tasks };
    } catch (error) {
        console.error("Error analyzing image:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Error processing image.",
            error.message
        );
    }
});

function parseDetections(detections) {
    // detections[0] is the full text
    // detections[1..n] are individual words/blocks

    // Known buckets
    const KNOWN_BUCKETS = [
        'Valla exterior',
        'Sala d\'estar',
        'Aigua',
        'Arquitectura/Planols',
        'Documentació',
        'Reforestació'
    ];

    const lines = groupWordsIntoLines(detections.slice(1));

    // Now classify lines as Header or Task
    const tasks = [];
    let currentBucket = 'General'; // Default

    for (const line of lines) {
        const lineText = line.text;

        // Check if line is a header
        const matched = findMatchingBucket(lineText, KNOWN_BUCKETS);
        if (matched) {
            currentBucket = matched;
        } else {
            // It's a task for the current bucket
            // Clean text
            let cleaned = lineText.replace(/^[\s\-\*vxy\[\]\.]+\s*/i, '').trim();
            if (cleaned.length > 0) {
                tasks.push({
                    title: cleaned,
                    bucket: currentBucket,
                    isDone: checkIsDone(lineText)
                });
            }
        }
    }

    return tasks;
}

function findMatchingBucket(text, buckets) {
    const lower = text.toLowerCase();
    for (const b of buckets) {
        // Fuzzy match: if the line contains significant parts of the bucket name
        const keywords = b.toLowerCase().split(/[\s/]+/);
        let matchCount = 0;
        for (const k of keywords) {
            if (k.length > 2 && lower.includes(k)) {
                matchCount++;
            }
        }
        // If we matched enough keywords or the whole thing
        if (matchCount > 0 || lower.includes(b.toLowerCase())) {
            return b;
        }
    }
    return null;
}

function checkIsDone(text) {
    return /^[xv]|\[x\]/i.test(text);
}

function groupWordsIntoLines(words) {
    // Sort by Y first
    words.sort((a, b) => a.boundingPoly.vertices[0].y - b.boundingPoly.vertices[0].y);

    const lines = [];

    for (const word of words) {
        let added = false;
        const wordY = word.boundingPoly.vertices[0].y;
        const wordH = word.boundingPoly.vertices[2].y - wordY;

        // Try to add to existing line if Y overlaps significantly
        for (const line of lines) {
            const lineY = line.y;
            if (Math.abs(wordY - lineY) < (wordH / 2 + 10)) {
                line.words.push(word);
                added = true;
                break;
            }
        }

        if (!added) {
            lines.push({
                y: wordY,
                words: [word],
                get text() {
                    // Sort line words by X
                    this.words.sort((a, b) => a.boundingPoly.vertices[0].x - b.boundingPoly.vertices[0].x);
                    return this.words.map(w => w.description).join(' ');
                }
            });
        }
    }

    return lines;
}

import { GoogleGenerativeAI } from "@google/generative-ai";

exports.identifyTree = functions.https.onCall(async (data, context) => {
    const imageBase64 = data.image;
    const mimeType = data.mimeType || "image/jpeg";

    if (!imageBase64) {
        throw new functions.https.HttpsError("invalid-argument", "Image data missing.");
    }

    // Initialize Gemini
    const apiKey = process.env.GEMINI_API_KEY || process.env.GEMINI_KEY;
    if (!apiKey) {
        throw new functions.https.HttpsError("failed-precondition", "Gemini API Key not configured.");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const prompt = `
    Analyze this image of a tree/plant acting as an expert in PERMACULTURE. Return a strict JSON object (no markdown) with the following fields:
    - species: Scientific name of the tree/plant.
    - commonName: Common name in Catalan (or Spanish if unknown).
    - status: One of "Viable", "Malalt", "Mort" based on visual health.
    - notes: A concise summary including water needs, ideal sun exposure, and observed health issues.
    - ecologicalFunction: Best fit from ["Nitrogenadora", "Fusta", "Fruit", "Tallavent/Visual", "Biomassa", "Ornamental"]. Default to "Ornamental" if unsure or "Fruit" if it bears edible fruit.
    - vigor: One of ["Alt", "Mitjà", "Baix"] based on visual lushness and growth.
    - maintenanceTips: A short paragraph in Catalan with specific maintenance advice (pruning, watering) using ONLY PERMACULTURE / ORGANIC methods (no chemicals).
    
    Example:
    {
      "species": "Quercus ilex",
      "commonName": "Alzina",
      "status": "Viable",
      "notes": "Necessita poc reg, ple sol.",
      "ecologicalFunction": "Fusta",
      "vigor": "Alt",
      "maintenanceTips": "Podar a l'hivern lleugerament. Aplicar encoixinat (mulching) per retenir humitat."
    }
    `;

    try {
        const imagePart = {
            inlineData: {
                data: imageBase64,
                mimeType: mimeType
            }
        };

        const result = await model.generateContent([prompt, imagePart]);
        const response = await result.response;
        const text = response.text();

        // Clean markdown code blocks if present
        const jsonStr = text.replace(/```json/g, '').replace(/```/g, '').trim();
        const info = JSON.parse(jsonStr);

        return info;
    } catch (error) {
        console.error("Gemini Error:", error);
        throw new functions.https.HttpsError("internal", "Failed to identify tree.", error.message);
    }
});

exports.analyzeTree = functions.https.onCall(async (data, context) => {
    let imageBase64 = data.image; // Option A: Direct Base64
    const imagePath = data.imagePath; // Option B: Storage Path

    if (!imageBase64 && !imagePath) {
        throw new functions.https.HttpsError("invalid-argument", "Must provide 'image' (base64) or 'imagePath'.");
    }

    if (!imageBase64 && imagePath) {
        try {
            const bucket = admin.storage().bucket();
            let path = imagePath;
            if (path.startsWith('gs://')) {
                const parts = path.split('/');
                path = parts.slice(3).join('/'); // Remove gs://bucket/
            }
            if (path.includes('?')) path = path.split('?')[0];
            if (path.includes('/o/')) {
                path = decodeURIComponent(path.split('/o/')[1]);
            }

            const [file] = await bucket.file(path).download();
            imageBase64 = file.toString('base64');
        } catch (e) {
            console.error("Storage Download Error:", e);
            throw new functions.https.HttpsError("internal", "Failed to download image from storage.");
        }
    }

    const apiKey = process.env.GEMINI_API_KEY || process.env.GEMINI_KEY;
    if (!apiKey) {
        throw new functions.https.HttpsError("failed-precondition", "Gemini API Key not configured. Run: firebase functions:config:set gemini.key=\"YOUR_KEY\"");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const species = data.species || "Unknown";
    const format = data.format || "Unknown";
    const location = data.location || "Unknown location";
    const date = data.date || new Date().toISOString().split('T')[0];
    const leafType = data.leafType || "Unknown";
    const age = data.age || "Unknown";
    const height = data.height ? `${data.height} cm` : "Unknown";
    const diameter = data.diameter ? `${data.diameter} cm` : "Unknown";
    const userQuestion = data.userQuestion || null;

    const prompt = `
    Act as an expert arborist specialized in PERMACULTURE and REGENERATIVE AGRICULTURE. Analyze the health of this tree based on the image and context.
    
    CRITICAL CONTEXT:
    - Species: ${species}
    - Leaf Type: ${leafType} (If 'Caduca' and date is winter, leafless is normal)
    - Date of Analysis: ${date}
    - Age/Format: ${format}, planted approx ${age} ago.
    - Measured Height: ${height}
    - Measured Trunk Diameter: ${diameter}
    - Location: ${location}

    Analyze the image considering the season and species characteristics.
    If it is winter and the tree is deciduous ('Caduca'), do NOT mark as 'Mort' or 'Malalt' just because it has no leaves, unless there are other signs of disease (bark issues, broken branches).

    IMPORTANT: ALL recommendations must be based on NATURAL, ORGANIC, and REGENERATIVE methods. 
    - AVOID chemical fertilizers or synthetic pesticides.
    - RECOMMEND natural solutions such as nettle slurry (purí d'ortigues), comfrey tea, worm castings (humus de cuc), compost tea, or mulching.
    - Focus on soil health and biodiversity.
    ${userQuestion ? `
    USER'S SPECIFIC QUESTION:
    The user has asked: "${userQuestion}"
    Please address this question specifically in your advice, in addition to the general analysis.
    ` : ''}
    Return a strict JSON object (no markdown) with:
    - health: One of "Viable", "Malalt", "Mort".
    - vigor: One of "Alt", "Mitjà", "Baix".
    - estimated_age_years: (float) Estimated visual age of the tree in years. Use the image (size, trunk thickness) and species growth rate context to estimate. If unsure, provide a best guess.
    - advice: A paragraph of advice and diagnosis in Catalan (Català). Mention specific visual indicators observed in the photo and relate them to the season/species context. Explain why you estimated the age if relevant. Ensure the advice applies permaculture principles (e.g., "Aplicar purí d'ortigues" instead of "Aplicar insecticida").${userQuestion ? " Make sure to directly answer the user's question at the beginning or end of your advice." : ''}

    Example JSON:
    {
      "health": "Malalt",
      "vigor": "Baix",
      "estimated_age_years": 5.5,
      "advice": "S'observa clorosi a les fulles, indicant falta de ferro. Es recomana aplicar quelats de ferro naturals o purí d'ortigues per millorar el sòl..."
    }
    `;

    try {
        const imagePart = {
            inlineData: {
                data: imageBase64,
                mimeType: "image/jpeg"
            }
        };

        const result = await model.generateContent([prompt, imagePart]);
        const response = await result.response;
        const text = response.text();
        const jsonStr = text.replace(/```json/g, '').replace(/```/g, '').trim();
        return JSON.parse(jsonStr);

    } catch (error) {
        console.error("Gemini Analysis Error:", error);
        throw new functions.https.HttpsError("internal", "AI Analysis Failed", error.message);
    }
});

exports.getBotanicalDataFromText = functions.https.onCall(async (data, context) => {
    const speciesName = data.speciesName;

    if (!speciesName) {
        throw new functions.https.HttpsError("invalid-argument", "The function must be called with a valid speciesName.");
    }

    const apiKey = process.env.GEMINI_API_KEY || process.env.GEMINI_KEY;
    if (!apiKey) {
        throw new functions.https.HttpsError("failed-precondition", "Gemini API Key not configured.");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
            temperature: 0.1,
        }
    });

    const prompt = `
    Ets un expert botànic agrícola de Catalunya. Per a l'espècie "${speciesName}", retorna EXCLUSIVAMENT un objecte JSON amb aquests camps:
    - nom_cientific: (text) Nom científic oficial.
    - nom_comu: (text) Nom comú principal en Català.
    - kc: (float) Coeficient de cultiu mitjà.
    - fulla: "Caduca" o "Perenne".
    - sensibilitat_gelada: (text) Descripció curta amb temperatura crítica, ex: "Alta (0ºC)" o "Baixa (-10ºC)".
    - mesos_poda: (array d'ints) Mesos numèrics (1-12) ideals per podar a Lleida.
    - mesos_collita: (array d'ints) Mesos numèrics (1-12) de collita a Lleida.
    - sol: Un d'aquests emojis segons necessitat: ☀️, 🌤️, ☁️.
    - fruit: (boolean) Si fa fruit comestible o aprofitable o no.
    - nom_fruit: (text) Nom del fruit (ex: "Poma", "Oliva", "Gla") o null si no en té.
    - alcada_adulta: (float) Alçada mitjana adulta en metres.
    - diametre_adult: (float) Diàmetre de capçada adult en metres.
    - ritme_creixement: (text) "Lent", "Mig" o "Ràpid".
    - resistencia_sequera: (int) De 1 (Poca) a 5 (Molta).
    - mesos_plantacio: (array d'ints) Mesos ideals per plantar (1-12).
    - mesos_floracio: (array d'ints) Mesos de floració (1-12).
    - esperanca_vida: (int) Esperança de vida mitjana en anys (ex: 80).
    - malalties_comunes: (array de strings) Top 3 malalties o plagues més freqüents (ex: ["Pulgó", "Oïdi", "Foc bacterià"]).

    Ajusta els valors per al clima de les Garrigues/Lleida (Hivern fred, Estiu calorós).
    Retorna només el JSON, sense markdown.
    `;

    try {
        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();
        const jsonStr = text.replace(/```json/g, '').replace(/```/g, '').trim();
        return JSON.parse(jsonStr);
    } catch (error) {
        console.error("Gemini Botany Error:", error);
        throw new functions.https.HttpsError("internal", "Failed to fetch botanical data.", error.message);
    }
});

exports.getHorticulturalData = functions.https.onCall(async (data, context) => {
    const speciesName = data.speciesName;

    if (!speciesName) {
        throw new functions.https.HttpsError("invalid-argument", "The function must be called with a valid speciesName.");
    }

    const apiKey = process.env.GEMINI_API_KEY || process.env.GEMINI_KEY;
    if (!apiKey) {
        throw new functions.https.HttpsError("failed-precondition", "Gemini API Key not configured.");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
            temperature: 0.1,
        }
    });

    const prompt = `
    Ets un expert en HORTICULTURA REGENERATIVA i PERMACULTURA amb especial coneixement del clima de PONENT (Lleida, Catalunya). 
    Objectiu: Proporcionar dades precises per a l'espècie "${speciesName}" cultivada a "La Floresta, Lleida" (Clima Continental: Hivern fred, Estiu molt calorós).
    
    Consulta (simuladament) bases de dades agronòmiques com les del DARP (Generalitat) o el "Calendari de l'Hortolà" per ajustar dates i rendiments.

    Retorna EXCLUSIVAMENT un objecte JSON amb aquests camps:
    - nom_cientific: (text) Nom científic.
    - nom_comu: (text) Nom comú principal en Català.
    - familia: (text) Família botànica.
    - part_comestible: Un de ["Fruit", "Fulla", "Arrel", "FlorLlegum"].
    
    - exigencia: Un de ["Molt exigent", "Mitjanament exigent", "Poc exigent", "Millorant"].
        * CLASSIFICACIÓ ESTRICTA:
        - "Molt exigent": Solanàcies, Cucurbitàcies, Panís, Coliflor.
        - "Mitjanament exigent": Bleda, Enciam, Pastanaga.
        - "Poc exigent": All, Ceba.
        - "Millorant": Lleguminoses (Fabàcies).

    - rendiment: (float) Rendiment estimat en kg/m2 per a cultiu intensiu-regeneratiu a l'aire lliure a Lleida. Sigues realista (ex: Tomata 6-8 kg/m2).
    - dies_cicle: (int) Dies aproximats des de plantació al camp fins a final de collita (o cicle complert).
    
    - tipus_sembra: Un de ["directa", "trasplantament"].
    - via_metabolica: Un de ["c3", "c4", "cam"].
    
    - distancia_plantes: (int) cm entre plantes.
    - distancia_linies: (int) cm entre línies/cavallons.
    
    - aliats: (array strings) 3-5 plantes companyes favorables.
    - enemics: (array strings) Plantes a evitar a prop.

    Retorna només el JSON.
    `;

    try {
        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();
        const jsonStr = text.replace(/```json/g, '').replace(/```/g, '').trim();
        return JSON.parse(jsonStr);
    } catch (error) {
        console.error("Gemini Horticulture Error:", error);
        throw new functions.https.HttpsError("internal", "Failed to fetch horticultural data.", error.message);
    }
});

/**
 * Scheduled function (Cron) to send daily task summary notifications.
 * Runs every 15 minutes to check if it's time to send based on FarmConfig.
 */
exports.dailyTaskSummary = functions.pubsub
    .schedule('*/15 * * * *')
    .timeZone('Europe/Madrid')
    .onRun(async (context) => {
        try {
            console.log('Running daily task summary scheduler...');

            // 1. Get Farm Configuration
            // 1. Get ALL Farm Configurations
            const fincasSnapshot = await admin.firestore().collection('finques').get();

            if (fincasSnapshot.empty) {
                console.log('No fincas found in configuration.');
                return null;
            }

            console.log(`Processing notifications for ${fincasSnapshot.size} fincas...`);

            // Iterate through each Finca
            for (const configDoc of fincasSnapshot.docs) {
                const config = configDoc.data();
                const fincaId = configDoc.id; // Use Doc ID as the Truth

                if (!fincaId || fincaId !== config.fincaId) {
                    console.log(`Warning: Finca ID mismatch or missing in doc ${configDoc.id}. Using doc ID.`);
                }

                // Get current time in Madrid
                const now = new Date();
                const madridDateStr = now.toLocaleString("en-US", { timeZone: "Europe/Madrid" });
                const madridNow = new Date(madridDateStr);
                const todayStr = madridNow.toISOString().split('T')[0];

                const updates = {};

                // --- MORNING NOTIFICATION (Tasks for TODAY) ---
                // Default 08:00 if not set
                if (config.morningNotificationsEnabled !== false) {
                    const morningTime = config.morningNotificationTime || '08:00';
                    const [mHour, mMinute] = morningTime.split(':').map(Number);
                    const morningTarget = new Date(madridNow);
                    morningTarget.setHours(mHour, mMinute, 0, 0);

                    // Check if time passed AND not sent yet
                    if (madridNow >= morningTarget && config.lastMorningNotificationDate !== todayStr) {
                        console.log(`Sending MORNING notification for ${todayStr}...`);

                        // Query for TODAY
                        const todayStart = new Date(madridNow);
                        todayStart.setHours(0, 0, 0, 0);
                        const todayEnd = new Date(madridNow);
                        todayEnd.setHours(23, 59, 59, 999);

                        // Shift for UTC (-2h safety)
                        const startMillis = todayStart.getTime() - (2 * 60 * 60 * 1000);
                        const endMillis = todayEnd.getTime() - (2 * 60 * 60 * 1000);

                        const sent = await checkAndSendNotification(
                            startMillis,
                            endMillis,
                            "remind_today", // type
                            "Bon dia! Feina per avui ☀️", // Title prefix
                            fincaId
                        );

                        if (sent) {
                            updates.lastMorningNotificationDate = todayStr;
                        }
                    }
                }

                // --- EVENING NOTIFICATION (Tasks for TOMORROW) ---
                if (config.dailyNotificationsEnabled !== false) {
                    const eveningTime = config.dailyNotificationTime || '20:30';
                    const [eHour, eMinute] = eveningTime.split(':').map(Number);
                    const eveningTarget = new Date(madridNow);
                    eveningTarget.setHours(eHour, eMinute, 0, 0);

                    // Check if time passed AND not sent yet
                    if (madridNow >= eveningTarget && config.lastNotificationDate !== todayStr) {
                        console.log(`Sending EVENING notification for ${todayStr}...`);

                        // Calculate "Tomorrow"
                        const tomorrow = new Date(madridNow);
                        tomorrow.setDate(tomorrow.getDate() + 1);
                        tomorrow.setHours(0, 0, 0, 0);

                        const endTomorrow = new Date(tomorrow);
                        endTomorrow.setHours(23, 59, 59, 999);

                        // Shift for UTC (-2h safety)
                        const startMillis = tomorrow.getTime() - (2 * 60 * 60 * 1000);
                        const endMillis = endTomorrow.getTime() - (2 * 60 * 60 * 1000);

                        const sent = await checkAndSendNotification(
                            startMillis,
                            endMillis,
                            "remind_tomorrow",
                            "Soca: Previsió per a demà 🌙",
                            fincaId
                        );

                        if (sent) {
                            updates.lastNotificationDate = todayStr; // Keep legacy name for evening
                        }
                    }
                }

                // Update Config if notifications were sent
                if (Object.keys(updates).length > 0) {
                    await configDoc.ref.update(updates);
                }
            } // End for loop

            return null;

        } catch (error) {
            console.error('Error in dailyTaskSummary:', error);
            return null;
        }
    });

/**
 * Helper to query tasks and send notification
 */
async function checkAndSendNotification(startMillis, endMillis, type, titlePrefix, fincaId) {
    const tasksSnapshot = await admin.firestore().collection('tasks')
        .where('dueDate', '>=', startMillis)
        .where('dueDate', '<=', endMillis)
        .where('isDone', '==', false)
        .where('fincaId', '==', fincaId) // Ensure we only count tasks for this finca
        .get();

    const taskCount = tasksSnapshot.size;
    console.log(`[${type}] Found ${taskCount} tasks for finca ${fincaId}.`);

    if (taskCount === 0) {
        console.log(`[${type}] No tasks, skipping.`);
        // Note: You might want to act differently (e.g. mark as sent anyway)
        // But for now we only update 'sent' flag if we actually try to send, 
        // OR we can decide that 0 tasks counts as "done" so we don't retry.
        // Let's return TRUE so we update the date and don't retry every 15 mins.
        return true;
    }

    // Get Recipients - Correctly filtered by Finca Authorization
    const usersSnapshot = await admin.firestore().collection('users')
        .where('authorizedFincas', 'array-contains', fincaId)
        .get();
    const tokens = [];

    usersSnapshot.forEach(doc => {
        const data = doc.data();

        // Check global notification setting (default true)
        if (data.dailyNotificationsEnabled !== false) {
            const userTokens = new Set();

            // 1. New Multi-Device Support
            if (data.fcmTokens) {
                Object.values(data.fcmTokens).forEach(device => {
                    if (device && device.token) {
                        userTokens.add(device.token);
                    }
                });
            }

            // 2. Legacy Support
            if (data.fcmToken) {
                userTokens.add(data.fcmToken);
            }

            // Add all unique tokens to the list
            userTokens.forEach(t => tokens.push(t));
        }
    });

    if (tokens.length === 0) {
        console.log(`[${type}] No users to notify.`);
        return true;
    }

    const taskTitles = [];
    tasksSnapshot.forEach(doc => {
        const data = doc.data();
        if (taskTitles.length < 3) {
            taskTitles.push(`• ${data.title}`);
        }
    });

    let body = taskTitles.join('\n');
    if (taskCount > 3) {
        body += `\n(+${taskCount - 3} més)`;
    }

    const targetDate = new Date(startMillis + (2 * 60 * 60 * 1000)); // Approx original date for navigation

    const payload = {
        notification: {
            title: `${titlePrefix} (${taskCount})`,
            body: body,
        },
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            route: "/tasks",
            date: targetDate.toISOString().split('T')[0]
        }
    };

    try {
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: payload.notification,
            data: payload.data
        });
        console.log(`[${type}] Sent: ${response.successCount}, Failed: ${response.failureCount}`);
        return true;
    } catch (e) {
        console.error(`[${type}] Send failed:`, e);
        return false;
    }
}

/**
 * Listener for Farm Config changes.
 * Propagates 'fincaId' to all relevant collections and updates User authorizations.
 */
exports.onFarmConfigWrite = functions.firestore
    .document('finques/{fincaId}')
    .onWrite(async (change, context) => {
        const newData = change.after.exists ? change.after.data() : null;
        const oldData = change.before.exists ? change.before.data() : null;

        if (!newData || !newData.fincaId) {
            console.log('No fincaId in new config or config deleted. Skipping propagation.');
            return null;
        }

        const fincaId = newData.fincaId;
        const oldFincaId = oldData ? oldData.fincaId : null;
        const authorizedEmails = newData.authorizedEmails || [];
        const oldEmails = oldData ? (oldData.authorizedEmails || []) : [];

        // 1. Check if we need to propagate fincaId (if changed or new)
        // For robustness, we can propagate if authorizedEmails changed too? No, only fincaId.
        // But if it's the SAME fincaId, we might want to skip heavy updates.
        // However, if it's a migration (adding previously missing ID), oldFincaId will be null.
        // if (fincaId !== oldFincaId) {
        console.log(`Forcing propagation of fincaId: '${fincaId}'...`);
        await propagateFincaId(fincaId);
        // }

        // 2. Update Users Authorization
        // We check if emails list changed OR fincaId changed.
        const emailsChanged = JSON.stringify(authorizedEmails) !== JSON.stringify(oldEmails);
        if (fincaId !== oldFincaId || emailsChanged) {
            console.log('Updating authorized users...');
            await updateAuthorizedUsers(fincaId, authorizedEmails);
        }

        return null;
    });

async function propagateFincaId(fincaId) {
    const db = admin.firestore();
    const batchHandler = new BatchHandler(db);

    // List of Root Collections
    const startCollections = [
        'trees',
        'tasks',
        'plantes_hort',
        'patrons_rotacio',
        'espais_hort',
        'clima_historic', // Root collection
        'construction_points', // Based on repository inspection
        'construction_plans', // New collection
        'species' // Added species
        // 'settings' is excluded generally, except specific docs, but we are in settings trigger.
    ];

    // 1. Update Root Collections
    for (const colName of startCollections) {
        console.log(`Queuing update for collection: ${colName}`);
        const snapshot = await db.collection(colName).get();
        snapshot.forEach(doc => {
            batchHandler.add(doc.ref, { fincaId: fincaId });
        });
    }

    // 2. Update Subcollections (using collectionGroup)
    // We must be careful not to update unrelated collections if names collide globally, 
    // but in this app schema names are unique enough or belong to this domain.
    const subCollections = [
        'regs', // trees/regs
        'evolucio', // trees/evolucio - Though migrated to seguiment, kept for safety?
        'seguiment', // trees/seguiment
        'historic_ia' // trees/historic_ia
    ];

    for (const subColName of subCollections) {
        console.log(`Queuing update for subcollection group: ${subColName}`);
        const snapshot = await db.collectionGroup(subColName).get();
        snapshot.forEach(doc => {
            batchHandler.add(doc.ref, { fincaId: fincaId });
        });
    }



    await batchHandler.commit();
    console.log(`Propagation complete. Total writes: ${batchHandler.totalWrites}`);
}

async function updateAuthorizedUsers(fincaId, authorizedEmails) {
    if (!authorizedEmails || authorizedEmails.length === 0) return;

    const db = admin.firestore();
    const usersRef = db.collection('users');
    const batchedWrites = [];

    // 1. Find users matching emails
    // Firestore 'in' query supports up to 10 items. If we expect >10 authorized emails, we need to chunk or loop.
    // Assuming small list for now. If > 10, logic needs split.
    // Let's assume < 10 for "my partner and me".

    // Safety check just in case
    const chunks = [];
    const chunkSize = 10;
    for (let i = 0; i < authorizedEmails.length; i += chunkSize) {
        chunks.push(authorizedEmails.slice(i, i + chunkSize));
    }

    for (const chunk of chunks) {
        const snapshot = await usersRef.where('email', 'in', chunk).get();

        if (snapshot.empty) continue;

        const batch = db.batch();
        let count = 0;

        snapshot.forEach(doc => {
            batch.update(doc.ref, {
                authorizedFincas: admin.firestore.FieldValue.arrayUnion(fincaId)
            });
            count++;
        });

        if (count > 0) {
            await batch.commit();
            console.log(`Updated ${count} users with fincaId authorization.`);
        }
    }
}

/**
 * Helper class to handle unlimited batch writes (chunks of 500)
 */
class BatchHandler {
    constructor(db) {
        this.db = db;
        this.batch = db.batch();
        this.counter = 0;
        this.totalWrites = 0;
    }

    add(ref, data) {
        this.batch.set(ref, data, { merge: true });
        this.counter++;
        if (this.counter >= 400) { // Limit is 500, keep safety margin
            return this.commit();
        }
        return Promise.resolve();
    }

    async commit() {
        if (this.counter === 0) return;
        await this.batch.commit();
        this.totalWrites += this.counter;
        console.log(`Batch committed: ${this.counter} writes.`);
        this.batch = this.db.batch();
        this.counter = 0;
    }
}

/**
 * TEMPORARY CLEANUP FUNCTION
 * Deletes users that do not have 'authorizedFincas' field.
 * Usage: https://us-central1-YOUR-PROJECT.cloudfunctions.net/cleanupLegacyUsers
 */
exports.cleanupLegacyUsers = functions.https.onRequest(async (req, res) => {
    try {
        const db = admin.firestore();
        console.log('Starting legacy user cleanup...');

        const usersSnapshot = await db.collection('users').get();
        let deletedCount = 0;

        let batch = db.batch();
        let batchCounter = 0;

        for (const doc of usersSnapshot.docs) {
            const data = doc.data();
            // Check if authorizedFincas is missing or empty
            if (!data.authorizedFincas || (Array.isArray(data.authorizedFincas) && data.authorizedFincas.length === 0)) {
                console.log(`Deleting legacy user: ${doc.id} (${data.email})`);
                batch.delete(doc.ref);
                batchCounter++;
                deletedCount++;

                if (batchCounter >= 400) {
                    await batch.commit();
                    batch = db.batch();
                    batchCounter = 0;
                }
            }
        }

        if (batchCounter > 0) {
            await batch.commit();
        }

        return res.status(200).send(`Cleanup complete. Deleted ${deletedCount} users.`);
    } catch (error) {
        console.error("Cleanup Error:", error);
        return res.status(500).send(`Cleanup Failed: ${error.message}`);
    }
});

/**
 * Public Species Card - HTTP endpoint
 * Renders a beautiful HTML card for a species from species_web collection.
 * Usage: /fitxa?id={speciesDocId}
 */
exports.speciesCard = functions.https.onRequest(async (req, res) => {
    const id = req.query.id as string;
    if (!id) {
        res.status(400).send("Missing 'id' parameter.");
        return;
    }

    try {
        const doc = await admin.firestore().collection('species_web').doc(id).get();
        if (!doc.exists) {
            res.status(404).send("Espècie no trobada.");
            return;
        }

        const s = doc.data()!;

        const monthNames = ['', 'Gen', 'Feb', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Des'];

        // Build activity row cells
        function buildActivityCells(months: number[], color: string): string {
            let cells = '';
            for (let m = 1; m <= 12; m++) {
                const active = (months || []).includes(m);
                cells += `<td class="act-cell ${active ? 'active' : ''}" style="${active ? `background:${color};` : ''}"></td>`;
            }
            return cells;
        }

        // Sun icon
        function sunIcon(needs: string): string {
            switch ((needs || '').toLowerCase()) {
                case 'alt': return '☀️';
                case 'mitjà': return '🌤️';
                case 'baix': return '☁️';
                default: return '☀️';
            }
        }

        // Drought resistance bar
        function droughtBar(val: number): string {
            let dots = '';
            for (let i = 1; i <= 5; i++) {
                dots += `<span class="dot ${i <= val ? 'filled' : ''}"></span>`;
            }
            return dots;
        }

        // Growth rate label
        function growthLabel(rate: string): string {
            switch (rate) {
                case 'Lent': return '🐢 Lent';
                case 'Mig': return '🌿 Mig';
                case 'Ràpid': return '🚀 Ràpid';
                default: return rate || '-';
            }
        }

        // Diseases list
        const diseases = (s.commonDiseases || []).map((d: string) => `<span class="disease-chip">${d}</span>`).join('');

        const speciesColor = s.color ? `#${s.color.replace('#', '')}` : '#4CAF50';

        const html = `<!DOCTYPE html>
<html lang="ca">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${s.commonName || 'Espècie'} — Soca</title>
    <meta name="description" content="Fitxa botànica de ${s.commonName} (${s.scientificName}) — Soca, gestió regenerativa del territori.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:ital,wght@0,700;1,400&display=swap" rel="stylesheet">
    <style>
        :root {
            --green-dark: #1B5E20;
            --green: #2E7D32;
            --green-light: #4CAF50;
            --green-pale: #E8F5E9;
            --bg: #F5F7F5;
            --white: #FFFFFF;
            --text: #1a1a1a;
            --text-light: #5a5a5a;
            --species-color: ${speciesColor};
            --radius: 16px;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
        }
        .card-container {
            max-width: 520px;
            margin: 24px auto;
            padding: 0 16px;
        }

        /* Header */
        .card-header {
            background: linear-gradient(135deg, #1B5E20 0%, #2E7D32 50%, #4CAF50 100%);
            border-radius: var(--radius) var(--radius) 0 0;
            padding: 32px 28px 24px;
            color: var(--white);
            position: relative;
            overflow: hidden;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
        }
        .card-header::before {
            content: '';
            position: absolute;
            top: -40px; right: -40px;
            width: 160px; height: 160px;
            background: rgba(255,255,255,0.06);
            border-radius: 50%;
        }
        .card-header::after {
            content: '';
            position: absolute;
            bottom: -60px; left: -30px;
            width: 120px; height: 120px;
            background: rgba(255,255,255,0.04);
            border-radius: 50%;
        }
        .logo-row {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 20px;
            position: relative;
            z-index: 1;
        }
        .logo-row img { height: 36px; filter: brightness(10); }
        .logo-row span {
            font-size: 18px;
            font-weight: 700;
            letter-spacing: 1px;
        }
        .species-name {
            font-family: 'Playfair Display', serif;
            font-size: 32px;
            font-weight: 700;
            line-height: 1.15;
            position: relative;
            z-index: 1;
        }
        .scientific {
            font-family: 'Playfair Display', serif;
            font-style: italic;
            font-size: 18px;
            opacity: 0.85;
            margin-top: 4px;
            position: relative;
            z-index: 1;
        }
        .color-dot {
            display: inline-block;
            width: 14px; height: 14px;
            border-radius: 50%;
            background: var(--species-color);
            border: 2px solid rgba(255,255,255,0.7);
            margin-right: 8px;
            vertical-align: middle;
        }

        /* Body */
        .card-body {
            background: var(--white);
            padding: 24px 28px;
        }

        /* Info Grid */
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin-bottom: 28px;
        }
        .info-item {
            display: flex;
            flex-direction: column;
        }
        .info-label {
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-light);
            margin-bottom: 4px;
        }
        .info-value {
            font-size: 16px;
            font-weight: 600;
            color: var(--text);
        }
        .info-value.big {
            font-size: 22px;
            color: var(--green);
        }

        /* Activity Table */
        .activity-section h3 {
            font-size: 14px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--green-dark);
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .activity-section h3::before {
            content: '';
            display: inline-block;
            width: 4px;
            height: 18px;
            background: var(--green-light);
            border-radius: 2px;
        }
        .activity-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 24px;
        }
        .activity-table th {
            font-size: 10px;
            font-weight: 600;
            color: var(--text-light);
            padding: 4px 0;
            text-align: center;
        }
        .activity-table td.act-label {
            font-size: 12px;
            font-weight: 600;
            padding: 6px 8px 6px 0;
            white-space: nowrap;
        }
        .act-cell {
            width: 28px;
            height: 24px;
            border-radius: 4px;
            transition: background 0.2s;
        }
        .act-cell.active {
            opacity: 0.9;
        }
        .act-cell:not(.active) {
            background: #f0f0f0;
        }

        /* Drought dots */
        .dot {
            display: inline-block;
            width: 10px; height: 10px;
            border-radius: 50%;
            background: #e0e0e0;
            margin-right: 3px;
        }
        .dot.filled { background: #2196F3; }

        /* Diseases */
        .diseases-row { margin-top: 16px; }
        .disease-chip {
            display: inline-block;
            background: #FFF3E0;
            color: #E65100;
            font-size: 12px;
            font-weight: 500;
            padding: 4px 10px;
            border-radius: 12px;
            margin: 3px 4px 3px 0;
        }

        /* Footer */
        .card-footer {
            background: var(--green-pale);
            border-radius: 0 0 var(--radius) var(--radius);
            padding: 16px 28px;
            text-align: center;
        }
        .card-footer p {
            font-size: 12px;
            color: var(--green);
            font-weight: 500;
        }
        .card-footer a {
            color: var(--green-dark);
            text-decoration: none;
            font-weight: 700;
        }

        /* Responsive */
        @media (max-width: 480px) {
            .card-container { margin: 0; padding: 0; }
            .card-header { border-radius: 0; padding: 24px 20px 20px; }
            .card-body { padding: 20px; }
            .card-footer { border-radius: 0; padding: 14px 20px; }
            .species-name { font-size: 24px; }
            .header-image { width: 90px; height: 90px; }
            .info-grid { gap: 12px; }
            .act-cell { width: 22px; height: 20px; }
        }

        /* Header Image Box */
        .header-image {
            width: 120px;
            height: 120px;
            background-size: cover;
            background-position: center;
            border-radius: 12px;
            border: 3px solid rgba(255, 255, 255, 0.4);
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
            flex-shrink: 0;
            background-color: rgba(255,255,255,0.1);
        }

        .header-main {
            flex: 1;
        }

        /* Links */
        .scientific a {
            color: inherit;
            text-decoration: none;
            border-bottom: 1px dashed rgba(255,255,255,0.4);
        }
        .scientific a:hover {
            color: var(--white);
            border-bottom-style: solid;
        }
        .scientific {
            font-style: italic;
            opacity: 0.9;
            margin-top: 4px;
        }
    </style>
    <link rel="icon" type="image/png" href="/assets/assets/logo-soca.png">
    <meta property="og:image" content="${s.image_url || ''}">
</head>
<body>
    <div class="card-container">
        <div class="card-header">
            <div class="header-main">
                <div class="logo-row">
                    <span>🌿 SOCA</span>
                </div>
                <div class="species-name"><span class="color-dot"></span>${s.commonName || '-'}</div>
                <div class="scientific">
                    <a href="https://www.google.com/search?q=${encodeURIComponent(s.scientificName || '')}" target="_blank" title="Cercar a Google">
                        ${s.scientificName || '-'}
                    </a>
                </div>
            </div>
            ${s.image_url ? `<div class="header-image" style="background-image: url('${s.image_url}')"></div>` : ''}
        </div>

        <div class="card-body">
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Coeficient de Cultiu</span>
                    <span class="info-value big">${s.kc ?? '-'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Fulla</span>
                    <span class="info-value">${s.leafType === 'Perenne' ? '🌲 Perenne' : '🍂 Caduca'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Necessitat de Sol</span>
                    <span class="info-value">${sunIcon(s.sunNeeds)} ${s.sunNeeds || '-'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Sensibilitat Gelades</span>
                    <span class="info-value">❄️ ${s.frostSensitivity || '-'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Alçada Adulta</span>
                    <span class="info-value">${s.adultHeight ? s.adultHeight + ' m' : '-'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Diàmetre</span>
                    <span class="info-value">${s.adultDiameter ? s.adultDiameter + ' m' : '-'}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Creixement</span>
                    <span class="info-value">${growthLabel(s.growthRate)}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Resistència Sequera</span>
                    <span class="info-value">${droughtBar(s.droughtResistance || 0)}</span>
                </div>
                ${s.fruit ? `
                <div class="info-item">
                    <span class="info-label">Fruit</span>
                    <span class="info-value">🍎 ${s.fruitType || 'Sí'}</span>
                </div>` : ''}
                ${s.lifeExpectancyYears ? `
                <div class="info-item">
                    <span class="info-label">Esperança de Vida</span>
                    <span class="info-value">⏳ ${s.lifeExpectancyYears} anys</span>
                </div>` : ''}
            </div>

            <div class="activity-section">
                <h3>Calendari d'Activitat</h3>
                <table class="activity-table">
                    <thead>
                        <tr>
                            <th></th>
                            ${monthNames.slice(1).map(n => `<th>${n}</th>`).join('')}
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td class="act-label">✂️ Poda</td>
                            ${buildActivityCells(s.pruningMonths || [], '#FF9800')}
                        </tr>
                        <tr>
                            <td class="act-label">🌱 Plantació</td>
                            ${buildActivityCells(s.plantingMonths || [], '#4CAF50')}
                        </tr>
                        <tr>
                            <td class="act-label">🧺 Collita</td>
                            ${buildActivityCells(s.harvestMonths || [], '#F44336')}
                        </tr>
                        <tr>
                            <td class="act-label">🌸 Floració</td>
                            ${buildActivityCells(s.floweringMonths || [], '#E91E63')}
                        </tr>
                    </tbody>
                </table>
            </div>

            ${(s.commonDiseases || []).length > 0 ? `
            <div class="diseases-row">
                <span class="info-label">🦠 Malalties Comunes</span>
                <div style="margin-top:6px">${diseases}</div>
            </div>` : ''}
        </div>

        <div class="card-footer">
            <p>Generat per <a href="https://soca-aacac.web.app">Soca</a> · Gestió regenerativa del territori. <a href="https://www.instagram.com/molicaljeroni" target="_blank">@molicaljeroni</a></p>
        </div>
    </div>
</body>
</html>`;

        // Temporary: 0 cache to allow immediate verification
        res.set('Cache-Control', 'public, max-age=0, s-maxage=0');
        res.status(200).send(html);

    } catch (error) {
        console.error("Species Card Error:", error);
        res.status(500).send("Error generant la fitxa.");
    }
});

// Import new TS Modules
import * as waterManagement from './water_management';
exports.manageWaterCycle = waterManagement.manageWaterCycle;
exports.manageWaterCycleAudit = waterManagement.manageWaterCycleAudit;

/**
 * Trigger: Update Image URL from Wikimedia when a species is created/updated in species_web
 */
exports.updateSpeciesImage = functions.firestore
    .document('species_web/{speciesId}')
    .onWrite(async (change, context) => {
        const after = change.after.exists ? change.after.data() : null;

        // Conditions to run:
        // 1. Document exists (not deleted)
        // 2. No image_url (or empty)
        // 3. Has scientificName
        if (!after || after.image_url) return null;

        const scientificName = after.scientificName;
        if (!scientificName) return null;

        console.log(`Fetching image for: ${scientificName}`);

        try {
            // Unsplash Source (Deprecated) -> Moving to Wikimedia Commons API
            // Query for page images
            const wikiUrl = `https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=pageimages&titles=${encodeURIComponent(scientificName)}&pithumbsize=800`;

            const response = await axios.get(wikiUrl, {
                headers: { 'User-Agent': 'SocaBot/1.0 (soca-aacac.web.app; contact@soca-aacac.web.app)' }
            });
            const pages = response.data?.query?.pages;

            if (!pages) return null;

            // Get first page result
            const pageId = Object.keys(pages)[0];
            if (pageId === '-1') return null; // Not found

            const imageUrl = pages[pageId]?.thumbnail?.source;

            if (imageUrl) {
                console.log(`Found image: ${imageUrl}`);
                // Update file
                return change.after.ref.update({ image_url: imageUrl });
            } else {
                console.log('No image found in Wikimedia response.');
            }

        } catch (error) {
            console.error('Error fetching image:', error.message);
            if (error.response) console.error('Response data:', error.response.data);
        }
        return null;
    });
