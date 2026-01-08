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
        // We can actually pass the gs:// URI to Vision API directly!
        // const bucketName = admin.storage().bucket().name; // Default bucket
        // const gcsUri = `gs://${bucketName}/${imagePath}`;

        // However, getting the bucket name can be tricky if not set explicitly.
        // Let's assume standard bucket.
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

        // 4. Cleanup? Maybe we delete the temp image later or let client do it.
        // Let's keep it simple.

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
    // We need to reconstruct lines and assign to headers.

    // This is a simplified heuristic. 
    // A robust implementation requires reconstructing paragraphs/lines from bounding boxes.

    // Known buckets
    const KNOWN_BUCKETS = [
        'Valla exterior',
        'Sala d\'estar',
        'Aigua',
        'Arquitectura/Planols',
        'Documentació',
        'Reforestació'
    ];

    const headers = [];
    const content = [];

    // Helper to get center Y
    const getCY = (poly) => (poly.vertices[0].y + poly.vertices[2].y) / 2;
    const getCX = (poly) => (poly.vertices[0].x + poly.vertices[1].x) / 2;

    // 1. Identify Headers in the raw blocks (skipping 0 which is full text)
    // Vision API splits by words usually in basic textDetection.
    // Ideally we use fullTextAnnotation.pages[0].blocks for paragraph detection which is better.

    // Let's try to infer lines from individual words for better granularity 
    // or just use the simplest approach: iterate words and map to nearest header above.

    // Actually, detections[0].description contains the full text with newlines. 
    // But we lose spatial info (bounding boxes) for the *lines* in [0].
    // [1..n] has boxes for words.

    // Let's identify "Header Words" first.
    // We group words that are close horizontally to form phrases.
    // But implementing a full layout engine here is hard.

    // Alternative: Use the full text and simple string parsing if the user 
    // writes headers clearly on separate lines. 
    // BUT the user wants "Mapeig intel·ligent...".

    // Let's assume the user writes the Header, and tasks below it.

    // Strategy:
    // 1. Find bounding boxes of words that match Bucket Keywords.
    // 2. Treat those as anchors.
    // 3. All other words are assigned to the closest anchor "above" them.

    const bucketAnchors = [];
    const otherWords = [];

    for (let i = 1; i < detections.length; i++) {
        const d = detections[i];
        const text = d.description.toLowerCase();

        // Check if this word is part of a bucket name
        let matchedBucket = null;
        for (const b of KNOWN_BUCKETS) {
            const parts = b.toLowerCase().split(/[\s/]+/);
            if (parts.includes(text) && text.length > 3) {
                matchedBucket = b;
                break;
            }
        }

        if (matchedBucket) {
            bucketAnchors.push({ bucket: matchedBucket, box: d.boundingPoly, text: d.description });
        } else {
            otherWords.push(d);
        }
    }

    // This is too fragmenty (word by word). 
    // Better to use the full text and standard grouping?
    // Let's stick to the heuristic:
    // Sort all words by Y.
    // Reconstruct lines.

    // ... Or just return raw lines and let Client do the heavy lifting?
    // User asked: "Firebase Function... retornar el text extret organitzat per línies"
    // AND "Lògica de Negoci: Manté el mapeig...".
    // So the FUNCTION should return the Tasks (mapped).

    // Let's try a simpler approach for the heuristic.
    // Group words into Lines based on Y coordinate overlap.

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
        // e.g. "Valla" in "Valla exterior"
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
            // Average Y of line
            const lineY = line.y;
            // If wordY is within lineY +/- height/2
            if (Math.abs(wordY - lineY) < (wordH / 2 + 10)) {
                line.words.push(word);
                // Update average Y? or keep simple
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
    // if (!context.auth) {
    //     throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    // }

    // image can be a base64 string or a GS URI. 
    // Ideally pass base64 for quick analysis or a gs:// path.
    // Let's support base64 for now as per plan to avoid upload latency for "preview".
    // data.image: base64 string (without data:image/jpeg;base64, prefix preferably, or strip it)
    // data.mimeType: 'image/jpeg'

    const imageBase64 = data.image;
    const mimeType = data.mimeType || "image/jpeg";

    if (!imageBase64) {
        throw new functions.https.HttpsError("invalid-argument", "Image data missing.");
    }

    // Initialize Gemini
    // Allow API key from env var or runtime config.
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
    // Input: { imagePath: string, species: string, format: string, location: string }

    // 1. Get Image
    let imageBase64 = data.image; // Option A: Direct Base64
    const imagePath = data.imagePath; // Option B: Storage Path

    if (!imageBase64 && !imagePath) {
        throw new functions.https.HttpsError("invalid-argument", "Must provide 'image' (base64) or 'imagePath'.");
    }

    if (!imageBase64 && imagePath) {
        // Download from Storage
        try {
            const bucket = admin.storage().bucket();
            // If imagePath is a full URL, we might need to parse it. 
            // Assuming imagePath is the relative path in the bucket (e.g. 'trees/xyz.jpg')
            // If the client sends the full download URL, we have a problem. Client should send the path.
            // Let's assume client sends relative path.

            // Handle if client sends full gs:// or http url (basic stripping)
            let path = imagePath;
            if (path.startsWith('gs://')) {
                const parts = path.split('/');
                path = parts.slice(3).join('/'); // Remove gs://bucket/
            }
            // Simple heuristic to remove query params if url
            if (path.includes('?')) path = path.split('?')[0];
            // If it's a full HTTPS url from firebase storage
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

    // 2. Setup Gemini
    const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini.key;
    if (!apiKey) {
        throw new functions.https.HttpsError("failed-precondition", "Gemini API Key not configured. Run: firebase functions:config:set gemini.key=\"YOUR_KEY\"");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    // Updated to available model from user list
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    // 3. Prompt
    const species = data.species || "Unknown";
    const format = data.format || "Unknown";
    const location = data.location || "Unknown location";
    const date = data.date || new Date().toISOString().split('T')[0]; // Current date context
    const leafType = data.leafType || "Unknown"; // Caduca/Perenne
    const age = data.age || "Unknown"; // e.g. "2 years"

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
    // Input: { speciesName: string }
    const speciesName = data.speciesName;

    if (!speciesName) {
        throw new functions.https.HttpsError("invalid-argument", "The function must be called with a valid speciesName.");
    }

    // Initialize Gemini
    const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini.key;
    if (!apiKey) {
        throw new functions.https.HttpsError("failed-precondition", "Gemini API Key not configured.");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

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
