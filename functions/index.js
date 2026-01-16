const functions = require("firebase-functions");
const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");

admin.initializeApp();

const client = new vision.ImageAnnotatorClient();

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

const { GoogleGenerativeAI } = require("@google/generative-ai");

exports.identifyTree = functions.https.onCall(async (data, context) => {
    const imageBase64 = data.image;
    const mimeType = data.mimeType || "image/jpeg";

    if (!imageBase64) {
        throw new functions.https.HttpsError("invalid-argument", "Image data missing.");
    }

    // Initialize Gemini
    const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini.key;
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

    const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini.key;
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

    Return a strict JSON object (no markdown) with:
    - health: One of "Viable", "Malalt", "Mort".
    - vigor: One of "Alt", "Mitjà", "Baix".
    - estimated_age_years: (float) Estimated visual age of the tree in years. Use the image (size, trunk thickness) and species growth rate context to estimate. If unsure, provide a best guess.
    - advice: A paragraph of advice and diagnosis in Catalan (Català). Mention specific visual indicators observed in the photo and relate them to the season/species context. Explain why you estimated the age if relevant. Ensure the advice applies permaculture principles (e.g., "Aplicar purí d'ortigues" instead of "Aplicar insecticida").

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

    const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini.key;
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

    const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini.key;
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
            const configDoc = await admin.firestore().collection('settings').doc('finca_config').get();
            if (!configDoc.exists) {
                console.log('No farm config found.');
                return null;
            }
            const config = configDoc.data();

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
                        "Bon dia! Feina per avui ☀️" // Title prefix
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
                        "Soca: Previsió per a demà 🌙"
                    );

                    if (sent) {
                        updates.lastNotificationDate = todayStr; // Keep legacy name for evening
                    }
                }
            }

            // Update Config if notifications were sent
            if (Object.keys(updates).length > 0) {
                await admin.firestore().collection('settings').doc('finca_config').update(updates);
                console.log('Config updated:', updates);
            }

            return null;

        } catch (error) {
            console.error('Error in dailyTaskSummary:', error);
            return null;
        }
    });

/**
 * Helper to query tasks and send notification
 */
async function checkAndSendNotification(startMillis, endMillis, type, titlePrefix) {
    const tasksSnapshot = await admin.firestore().collection('tasks')
        .where('dueDate', '>=', startMillis)
        .where('dueDate', '<=', endMillis)
        .where('isDone', '==', false)
        .get();

    const taskCount = tasksSnapshot.size;
    console.log(`[${type}] Found ${taskCount} tasks.`);

    if (taskCount === 0) {
        console.log(`[${type}] No tasks, skipping.`);
        // Note: You might want to act differently (e.g. mark as sent anyway)
        // But for now we only update 'sent' flag if we actually try to send, 
        // OR we can decide that 0 tasks counts as "done" so we don't retry.
        // Let's return TRUE so we update the date and don't retry every 15 mins.
        return true;
    }

    // Get Recipients
    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = [];

    usersSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.fcmToken && data.dailyNotificationsEnabled !== false) {
            tokens.push(data.fcmToken);
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
