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
    Analyze this image of a tree. Return a strict JSON object (no markdown) with the following fields:
    - species: Scientific name of the tree.
    - commonName: Common name in Catalan (or Spanish if unknown).
    - status: One of "Viable", "Malalt", "Mort" based on visual health.
    - notes: A concise summary including water needs, ideal sun exposure, and observed health issues.
    
    Example:
    {
      "species": "Quercus ilex",
      "commonName": "Alzina",
      "status": "Viable",
      "notes": "Necessita poc reg, ple sol. Fulles sanes."
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

    const prompt = `
    Act as an expert arborist. Analyze the health of this tree based on the image and context.
    
    CRITICAL CONTEXT:
    - Species: ${species}
    - Leaf Type: ${leafType} (If 'Caduca' and date is winter, leafless is normal)
    - Date of Analysis: ${date}
    - Age/Format: ${format}, planted approx ${age} ago.
    - Location: ${location}

    Analyze the image considering the season and species characteristics.
    If it is winter and the tree is deciduous ('Caduca'), do NOT mark as 'Mort' or 'Malalt' just because it has no leaves, unless there are other signs of disease (bark issues, broken branches).

    Return a strict JSON object (no markdown) with:
    - health: One of "Viable", "Malalt", "Mort".
    - vigor: One of "Alt", "Mitjà", "Baix".
    - advice: A paragraph of advice and diagnosis in Catalan (Català). Mention specific visual indicators observed in the photo and relate them to the season/species context.

    Example JSON:
    {
      "health": "Malalt",
      "vigor": "Baix",
      "advice": "S'observa clorosi a les fulles, indicant falta de ferro..."
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

            if (config.dailyNotificationsEnabled === false) {
                console.log('Daily notifications are disabled in FarmConfig.');
                return null;
            }

            // 2. Check Time
            const targetTimeStr = config.dailyNotificationTime || '20:30';
            const [targetHour, targetMinute] = targetTimeStr.split(':').map(Number);

            // Get current time in Madrid
            const now = new Date();
            const madridDateStr = now.toLocaleString("en-US", { timeZone: "Europe/Madrid" });
            const madridNow = new Date(madridDateStr);

            // Construct Target Date for "Today"
            const targetDate = new Date(madridNow);
            targetDate.setHours(targetHour, targetMinute, 0, 0);

            // Check if we HAVE PASSED the target time (e.g. Now is 21:00, Target was 20:30)
            if (madridNow < targetDate) {
                console.log(`Not yet time (` + madridNow.toISOString() + `). Target: ${targetTimeStr}`);
                return null;
            }

            // 3. Check Idempotency (Have we sent it today?)
            const todayStr = madridNow.toISOString().split('T')[0];
            if (config.lastNotificationDate === todayStr) {
                console.log('Notification already sent today.');
                return null;
            }

            console.log('Time reached. Preparing to send notification...');

            // --- CORE LOGIC (Calculate and Send) ---

            // Calculate "Tomorrow"
            const tomorrow = new Date(madridNow);
            tomorrow.setDate(tomorrow.getDate() + 1);
            tomorrow.setHours(0, 0, 0, 0);

            const endTomorrow = new Date(tomorrow);
            endTomorrow.setHours(23, 59, 59, 999);

            const startMillis = tomorrow.getTime();
            const endMillis = endTomorrow.getTime();

            const tasksSnapshot = await admin.firestore().collection('tasks')
                .where('dueDate', '>=', startMillis)
                .where('dueDate', '<=', endMillis)
                .where('isDone', '==', false)
                .get();

            const taskCount = tasksSnapshot.size;
            console.log(`Found ${taskCount} tasks for tomorrow.`);

            if (taskCount > 0) {
                // Get Recipients
                const usersSnapshot = await admin.firestore().collection('users').get();
                const tokens = [];

                usersSnapshot.forEach(doc => {
                    const data = doc.data();
                    if (data.fcmToken && data.dailyNotificationsEnabled !== false) {
                        tokens.push(data.fcmToken);
                    }
                });

                if (tokens.length > 0) {
                    const payload = {
                        notification: {
                            title: 'Soca: Previsió per a demà',
                            body: `Tens ${taskCount} tasques pendents per a demà. Fes clic per veure el resum.`,
                        },
                        data: {
                            click_action: 'FLUTTER_NOTIFICATION_CLICK',
                            route: '/tasks',
                            date: tomorrow.toISOString()
                        }
                    };

                    const response = await admin.messaging().sendEachForMulticast({
                        tokens: tokens,
                        notification: payload.notification,
                        data: payload.data
                    });
                    console.log(`Notifications sent: ${response.successCount} success.`);
                } else {
                    console.log('No tokens found.');
                }
            } else {
                console.log('No tasks found, skipping message.');
            }

            // 4. Update Idempotency Flag
            await admin.firestore().collection('settings').doc('finca_config').update({
                lastNotificationDate: todayStr,
                lastNotificationTimestamp: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`Marked notification as sent for ${todayStr}`);

            return null;

        } catch (error) {
            console.error('Error in dailyTaskSummary:', error);
            return null;
        }
    });
