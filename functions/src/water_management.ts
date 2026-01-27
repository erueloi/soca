import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import axios from 'axios';

// Constants
const METEOCAT_API_KEY = process.env.METEOCAT_KEY || 'R5F8gNLcUw7Hr6KIiIS6w8INP3juJpjn6SxavYBB'; // Fallback to known key
const METEOCAT_BASE_URL = 'https://api.meteo.cat/xema/v1';
const STATION_CODE = 'YD'; // Les Borges Blanques



/**
 * CRON: 00:01 daily (Audit/Close yesterday)
 * CRON: 08:00, 14:00, 22:00 daily (Live updates)
 */
export const manageWaterCycle = functions.pubsub
    .schedule('0 8,14,22 * * *') // Live updates
    .timeZone('Europe/Madrid')
    .onRun(async (context) => {
        console.log('Starting manageWaterCycle...');

        // 1. Determine Mode (Audit vs Live)
        const now = new Date();
        const hour = now.getHours();
        const isAudit = (hour === 0);

        // 2. Run Step 1: Data Acquisition
        const dataSuccess = await step1_DataAcquisition(isAudit);
        if (!dataSuccess && !isAudit) {
            console.log('Data acquisition failed (quota or error). Skipping Recalc.');
            return null;
        }

        // 3. Run Step 2: Global Recalculation & Trees
        await step2_GlobalRecalculation();

        return null;
    });

export const manageWaterCycleAudit = functions.pubsub
    .schedule('1 0 * * *') // 00:01
    .timeZone('Europe/Madrid')
    .onRun(async (context) => {
        console.log('Starting AUDIT manageWaterCycle...');
        // Force retry logic for audit
        await step1_DataAcquisition(true); // isAudit = true
        await step2_GlobalRecalculation();
    });


// --- STEP 1: DATA ACQUISITION ---

async function step1_DataAcquisition(isAudit: boolean): Promise<boolean> {
    const db = admin.firestore();
    const quotaRef = db.collection('config').doc('meteocat_quota');

    // 1. Check Quota
    if (!isAudit) {
        const quotaDoc = await quotaRef.get();
        const quotaData = quotaDoc.data() || { count: 0, date: '' };
        const todayStr = new Date().toISOString().split('T')[0];

        if (quotaData.date === todayStr && quotaData.count >= 4) {
            console.warn('Quota Exceeded (4/4). Skipping live update.');
            return false;
        }
    }

    // 2. Fetch Data (Meteocat)
    try {
        console.log(`Fetching Meteocat data (Audit: ${isAudit})...`);
        const today = new Date();
        const targetDate = isAudit
            ? new Date(today.getTime() - 24 * 60 * 60 * 1000) // Yesterday
            : today; // Today

        const y = targetDate.getFullYear();
        const m = (targetDate.getMonth() + 1).toString().padStart(2, '0');
        const d = targetDate.getDate().toString().padStart(2, '0');

        const url = `${METEOCAT_BASE_URL}/estacions/mesurades/${STATION_CODE}/${y}/${m}/${d}`;

        const response = await axios.get(url, {
            headers: { 'X-Api-Key': METEOCAT_API_KEY }
        });

        const dataList = response.data;
        if (!dataList || dataList.length === 0) {
            console.error('Empty response from Meteocat');
            return false;
        }

        const stationData = dataList[0]; // Assuming 1 station requested
        const vars = stationData.variables || [];

        // Parse Variables
        const parsed = parseMeteoVariables(vars);

        // Calculate ET0 (Penman-Monteith subset/Hargreaves or simplified)
        const et0 = calculateET0(parsed, 41.5117); // Lat of La Floresta

        // Pef Calculation
        // let pef = 0; // Unused variable removed, calculated later
        // if (parsed.rain >= 4.0) { pef = parsed.rain * 0.75; }

        // 3. Persist "Facts"
        const dateStr = `${y}-${m}-${d}`;
        const docId = dateStr;
        const entry: any = {
            date: dateStr,
            maxTemp: parsed.maxTemp,
            minTemp: parsed.minTemp,
            rain: parsed.rain,
            rainAccumulated: parsed.rainAccumulated,
            humidity: parsed.humidity,
            radiation: parsed.radiation,
            windSpeed: parsed.windSpeed,
            et0: et0,
            fincaId: 'mol-cal-jeroni', // HARDCODED for now
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            isMock: false
        };

        // Merge!
        await db.collection('clima_historic').doc(docId).set(entry, { merge: true });

        // Update Quota (if not audit)
        if (!isAudit) {
            const todayStr = new Date().toISOString().split('T')[0];
            await quotaRef.set({
                count: admin.firestore.FieldValue.increment(1),
                date: todayStr,
                last_success: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
        }

        console.log(`Step 1 Complete. Data saved for ${dateStr}.`);
        return true;

    } catch (e: any) {
        console.error('Meteocat API Error:', e.message);
        return false;
    }
}


// --- STEP 2: GLOBAL RECALCULATION & TREES ---

async function step2_GlobalRecalculation() {
    console.log('Starting Step 2: Global Recalculation...');
    const db = admin.firestore();
    const batchHandler = new BatchHandler(db);

    // --- PART A: GLOBAL CLIMATE ---
    const now = new Date();
    // Use yesterday as the "reference day" for balance calculation if running at 00:01
    // But typically we recalculate the whole month to catch up.
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfMonthStr = startOfMonth.toISOString().split('T')[0];

    // Using simple string comparison for YYYY-MM-DD
    const snapshot = await db.collection('clima_historic')
        .where('fincaId', '==', 'mol-cal-jeroni') // Optional optimization
        .where('date', '>=', startOfMonthStr)
        .orderBy('date', 'asc')
        .get();

    if (snapshot.empty) {
        console.log('No climate data found for this month.');
        return;
    }

    // 1. Calculate and Update Global Balance
    let currentBalance = 0.0;

    const dailyDataList: any[] = [];
    snapshot.docs.forEach(doc => dailyDataList.push({ id: doc.id, ...doc.data() }));
    // Sort just in case alphanumeric sort works for ISO dates
    dailyDataList.sort((a, b) => a.date.localeCompare(b.date));

    // Keep track of the latest available day to use for Tree calculations
    let latestDayData: any = null;

    for (const day of dailyDataList) {
        // Pef
        let pef = 0;
        if (day.rain >= 4.0) pef = day.rain * 0.75;

        // ETc
        const kc = 0.6; // Standard Kc for global balance
        const et0 = day.et0 || 0;
        const etc = et0 * kc;

        // Balance
        let rawBalance = currentBalance + pef - etc;
        if (rawBalance > 35.0) rawBalance = 35.0;

        currentBalance = rawBalance;

        // Update Global Doc
        batchHandler.add(db.collection('clima_historic').doc(day.id), {
            soilBalance: currentBalance,
            calculatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        latestDayData = day; // Keep track of the last processed day
        latestDayData.pef = pef; // Store calculated Pef
    }

    await batchHandler.commit(); // Save Climate Updates

    if (!latestDayData) return;

    // --- PART B: INDIVIDUAL TREES ---
    // We only update trees relative to the LATEST data available.

    console.log(`Starting Tree Updates for date: ${latestDayData.date}`);

    // 1. Fetch Irrigations for this specific Date (Global query for efficiency)
    const dateParts = latestDayData.date.split('-');
    const dayStart = new Date(Number(dateParts[0]), Number(dateParts[1]) - 1, Number(dateParts[2]));
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

    console.log(`Fetching irrigations between ${dayStart.toISOString()} and ${dayEnd.toISOString()}...`);

    const regsSnapshot = await db.collectionGroup('regs')
        .where('date', '>=', admin.firestore.Timestamp.fromDate(dayStart))
        .where('date', '<', admin.firestore.Timestamp.fromDate(dayEnd))
        .get();

    const irrigationMap = new Map<string, number>(); // TreeID -> Liters
    regsSnapshot.forEach(doc => {
        const data = doc.data();
        // Assume structure trees/{treeId}/regs/{docId}
        const treeId = doc.ref.parent.parent?.id;
        if (treeId) {
            const liters = Number(data.litres || data.liters || 0);
            const current = irrigationMap.get(treeId) || 0;
            irrigationMap.set(treeId, current + liters);
        }
    });

    console.log(`Found ${regsSnapshot.size} irrigation events for ${irrigationMap.size} trees.`);

    // 2. Fetch All Trees
    const treesSnapshot = await db.collection('trees')
        // .where('fincaId', '==', 'mol-cal-jeroni') // Optional
        .where('status', '==', 'Viable') // Only update valid trees
        .get();

    console.log(`Processing ${treesSnapshot.size} trees...`);

    // 3. Init Batch for Trees
    const treeBatchHandler = new BatchHandler(db);

    for (const doc of treesSnapshot.docs) {
        const tree = doc.data();

        // --- START OF DAY BALANCE DETERMINATION ---
        let startOfDayVal = tree.startOfDayBalance;

        // Migration/First Run:
        if (startOfDayVal === undefined) {
            startOfDayVal = tree.soilBalance || 0;
        }

        // Check if we are running for the SAME day or a NEW day
        const lastUpdateTimestamp = tree.lastBalanceUpdate; // Timestamp
        let isSameDayRun = false;
        if (lastUpdateTimestamp) {
            const lastDate = lastUpdateTimestamp.toDate();
            // Compare YYYY-MM-DD
            if (lastDate.toISOString().split('T')[0] === latestDayData.date) {
                isSameDayRun = true;
            }
        }

        if (!isSameDayRun) {
            // It's a NEW day. The previous 'soilBalance' (end of yesterday) is now our startOfDayBalance.
            // But wait, if we skipped days? 
            // Ideally we should process day-by-day. But for MVP we jump to current.
            // We assume 'soilBalance' reflects the state at the end of the last update.
            startOfDayVal = tree.soilBalance || 0;
        }

        // --- CALCULATION ---

        // 1. Area (Step D)
        const diameterCm = tree.trunkDiameter || 0;
        let areaRadius = 0.4; // < 5cm -> 0.8m diam -> 0.4 radius
        if (diameterCm >= 5 && diameterCm <= 15) areaRadius = 0.75; // 1.5m diam
        if (diameterCm > 15) areaRadius = 1.5; // 3.0m diam (Ample Biblioteca)

        const area = Math.PI * (areaRadius * areaRadius); // m2

        // 2. Irrigation Delta
        const liters = irrigationMap.get(doc.id) || 0;
        const irrigMm = (liters / area); // L/m2 = mm

        // 3. ETc Tree
        const kc = tree.coeficient_kc || 0.6; // Default standard
        const etc = (latestDayData.et0 || 0) * kc;

        // 4. Balance
        // Balance = Start + Pef + Irrig - ETc
        let newBalance = startOfDayVal + (latestDayData.pef || 0) + irrigMm - etc;

        // Cap (Max 35.0 similar to global)
        if (newBalance > 35.0) newBalance = 35.0;

        treeBatchHandler.add(doc.ref, {
            soilBalance: newBalance, // Updated Balance (End of Day state)
            startOfDayBalance: startOfDayVal, // Persist for re-runs today
            lastBalanceUpdate: admin.firestore.Timestamp.fromDate(dayStart), // Mark as updated for THIS day
            calculatedRegArea: area // Store for debug/UI
        });
    }

    await treeBatchHandler.commit();
    console.log(`Trees updated.`);
}


// --- HELPERS ---

function parseMeteoVariables(vars: any[]): any {
    // Defaults
    const out = {
        maxTemp: 20, minTemp: 10, rain: 0, rainAccumulated: 0,
        humidity: 60, radiation: 15, windSpeed: 2
    };

    vars.forEach(v => {
        const val = v.valor;
        if (val === undefined || val === null) return; // Skip invalid values

        switch (v.codi) {
            case 40: out.maxTemp = Number(val); break; // Tx
            case 42: out.minTemp = Number(val); break; // Tn
            case 35: out.rain = Number(val); break; // Rain
            case 33: out.humidity = Number(val); break; // RH
        }
    });

    if (out.rain < 0) out.rain = 0;
    out.rainAccumulated = out.rain;
    return out;
}

function calculateET0(data: any, lat: number): number {
    // Hargreaves (Simplified)
    const tMean = (data.maxTemp + data.minTemp) / 2;
    return 0.0023 * (tMean + 17.78) * Math.sqrt(data.maxTemp - data.minTemp) * 15.0;
}

/**
 * Helper class to handle unlimited batch writes (chunks of 400)
 */
class BatchHandler {
    private db: admin.firestore.Firestore;
    private batch: admin.firestore.WriteBatch;
    private counter: number;
    public totalWrites: number;

    constructor(db: admin.firestore.Firestore) {
        this.db = db;
        this.batch = db.batch();
        this.counter = 0;
        this.totalWrites = 0;
    }

    add(ref: admin.firestore.DocumentReference, data: any) {
        this.batch.set(ref, data, { merge: true });
        this.counter++;
        if (this.counter >= 400) {
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
