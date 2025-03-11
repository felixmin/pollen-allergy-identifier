/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as functions from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import axios from "axios";
import * as dotenv from 'dotenv';
import * as path from 'path';
import { CallableRequest } from "firebase-functions/v2/https";

// Initialize dotenv
dotenv.config({ path: path.resolve(__dirname, '.env') });

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// Initialize Firebase Admin SDK
try {
  admin.initializeApp();
  logger.info("Firebase Admin SDK initialized successfully");
} catch (error) {
  logger.error("Error initializing Firebase Admin SDK:", error);
  // If it's already initialized, that's fine
  if (error instanceof Error && error.message.includes('already exists')) {
    logger.info("Firebase Admin SDK was already initialized");
  }
}

// Helper function to validate feedback data
function validateFeedbackData(data: any): { validatedData: any | null; error: string | null } {
  logger.info("Validating data:", data);
  
  if (data === null || data === undefined) {
    return { validatedData: null, error: "Missing data payload" };
  }

  if (data.feedback === undefined || data.feedback === null) {
    return { validatedData: null, error: "Missing required field: 'feedback'" };
  }

  if (data.location === undefined || data.location === null) {
    return { validatedData: null, error: "Missing required field: 'location'" };
  }

  const location = data.location;
  if (location.lat === undefined || location.lng === undefined) {
    return { validatedData: null, error: "Location must include 'lat' and 'lng'" };
  }

  // Convert lat/lng to numbers if they're strings
  if (typeof location.lat === 'string') {
    location.lat = parseFloat(location.lat);
  }
  
  if (typeof location.lng === 'string') {
    location.lng = parseFloat(location.lng);
  }

  // Validate lat/lng are valid numbers
  if (isNaN(location.lat) || isNaN(location.lng)) {
    return { validatedData: null, error: "Location coordinates must be valid numbers" };
  }

  // Ensure pollenData exists (it will be replaced later with API data)
  data.pollenData = data.pollenData || [];
  
  return { validatedData: data, error: null };
}

// Helper function to get pollen data from Google Pollen API
async function getPollenData(lat: number, lng: number): Promise<any[]> {
  const apiKey = "AIzaSyDAx6YC-zeiHA-ax7sOHu3e_kHR4Do4u0k";
  if (!apiKey) {
    logger.warn("POLLEN_API_KEY not set in environment");
    // Return empty array but don't fail the function
    return [];
  }

  const params = {
    key: apiKey,
    "location.latitude": lat,
    "location.longitude": lng,
    days: 1
  };

  try {
    const response = await axios.get("https://pollen.googleapis.com/v1/forecast:lookup", { params });
    const apiData = response.data;
    const pollenData: any[] = [];
    const dailyInfo = apiData.dailyInfo || [];
    
    if (dailyInfo.length > 0) {
      const firstDay = dailyInfo[0];
      // Process both general and plant-specific pollen info if available
      ["pollenTypeInfo", "plantInfo"].forEach(field => {
        const items = firstDay[field] || [];
        items.forEach((item: any) => {
          const indexInfo = item.indexInfo;
          if (indexInfo) {
            pollenData.push({
              pollenType: (item.displayName || "").toLowerCase(),
              exposureLevel: indexInfo.value
            });
          }
        });
      });
    }
    return pollenData;
  } catch (e) {
    logger.error(`Error querying pollen API: ${e}`);
    return [];
  }
}

// Helper function to store feedback in Firestore
async function storeFeedback(userId: string, feedbackData: any, pollenData: any[]): Promise<{ docRef: FirebaseFirestore.DocumentReference | null; error: string | null }> {
  try {
    const db = admin.firestore();
    
    // Use a regular JavaScript Date instead of Firestore Timestamp
    const now = new Date();
    
    logger.info("Creating feedback document with timestamp:", now);
    
    const feedbackDoc = {
      userId: userId,
      timestamp: now,
      feedback: feedbackData.feedback,
      location: {
        lat: feedbackData.location.lat,
        lng: feedbackData.location.lng
      },
      pollenData: pollenData
    };

    const docRef = await db.collection("feedback").add(feedbackDoc);
    logger.info("Document created with ID:", docRef.id);
    return { docRef, error: null };
  } catch (e) {
    logger.error("Error in storeFeedback:", e);
    return { docRef: null, error: `Error writing to Firestore: ${e}` };
  }
}

// Helper function to analyze pollen correlation
async function analyzePollenCorrelation(userId: string): Promise<{ result: any | null; error: string | null }> {
  const db = admin.firestore();
  
  try {
    // Retrieve all feedback documents for this user
    const querySnapshot = await db.collection("feedback").where("userId", "==", userId).get();
    
    // Collect all feedback entries with their pollen data
    const feedbackEntries: Array<{feedback: number, pollenData: any[]}> = [];
    
    querySnapshot.forEach(doc => {
      const data = doc.data();
      
      // Skip entries with missing data
      if (data.feedback === undefined || data.feedback === null || !data.pollenData) {
        return;
      }
      
      // Convert feedback to numeric value if it's not already
      let feedbackValue = data.feedback;
      if (typeof feedbackValue === 'string') {
        try {
          feedbackValue = parseFloat(feedbackValue);
        } catch (e) {
          // If feedback is categorical (e.g. "good", "bad"), skip
          return;
        }
      }
      
      // Add entry to our collection - include ALL feedback values, even zero
      feedbackEntries.push({
        feedback: feedbackValue,
        pollenData: data.pollenData || []
      });
    });
    
    logger.info(`Collected ${feedbackEntries.length} feedback entries for analysis`);
    
    // Group pollen data by type across all entries
    const pollenTypes = new Set<string>();
    feedbackEntries.forEach(entry => {
      entry.pollenData.forEach(item => {
        if (item.pollenType) {
          pollenTypes.add(item.pollenType);
        }
      });
    });
    
    logger.info(`Found ${pollenTypes.size} unique pollen types`);
    
    // Calculate correlations for each pollen type independently
    const correlations: Record<string, any> = {};
    
    pollenTypes.forEach(pollenType => {
      // For each pollen type, filter entries where this pollen type exists
      const filteredEntries = feedbackEntries.filter(entry => 
        entry.pollenData.some(item => item.pollenType === pollenType)
      );
      
      // Skip if we don't have enough data points
      if (filteredEntries.length < 3) {
        logger.info(`Skipping ${pollenType}: only ${filteredEntries.length} entries have this pollen type (need at least 3)`);
        return;
      }
      
      // Extract feedback values and exposure levels for this pollen type
      const feedbackValues: number[] = [];
      const exposureLevels: number[] = [];
      
      filteredEntries.forEach(entry => {
        const pollenItem = entry.pollenData.find(item => item.pollenType === pollenType);
        // Modified condition to ensure we include zero values (only exclude undefined/null)
        if (pollenItem && pollenItem.exposureLevel !== undefined && pollenItem.exposureLevel !== null) {
          feedbackValues.push(entry.feedback);
          exposureLevels.push(pollenItem.exposureLevel);
        }
      });
      
      // Double-check we still have enough data points after filtering
      if (feedbackValues.length < 3) {
        logger.info(`Skipping ${pollenType}: only ${feedbackValues.length} valid data points after filtering (need at least 3)`);
        return;
      }
      
      // Check for zero variance
      if (new Set(exposureLevels).size === 1 || new Set(feedbackValues).size === 1) {
        correlations[pollenType] = {
          correlation: 0,  // Zero correlation when one variable is constant
          p_value: 1.0,    // Not significant
          significant: false,
          error: "Zero variance in data"
        };
        return;
      }
      
      // Calculate Pearson correlation coefficient
      try {
        const correlation = calculateCorrelation(exposureLevels, feedbackValues);
        const p_value = estimatePValue(correlation, feedbackValues.length);
        
        // Store correlation data
        correlations[pollenType] = {
          correlation,
          p_value,
          significant: p_value < 0.05
        };
        
        logger.info(`Calculated correlation for ${pollenType}: ${correlation} (p=${p_value})`);
      } catch (e) {
        correlations[pollenType] = {
          correlation: 0,
          p_value: 1.0,
          significant: false,
          error: String(e)
        };
        
        logger.error(`Error calculating correlation for ${pollenType}: ${e}`);
      }
    });
    
    // Log correlation results
    logger.info("Correlation results:", {
      totalPollenTypes: pollenTypes.size,
      correlationsCalculated: Object.keys(correlations).length
    });
    
    // Prepare result
    const result = {
      userId,
      dataPoints: feedbackEntries.length,
      correlations,
      analyzedAt: new Date()
    };
    
    // Store the analysis result in a "results" collection
    await db.collection("results").doc(userId).set(result);
    
    return { result, error: null };
  } catch (e) {
    return { result: null, error: `Error analyzing pollen correlation: ${e}` };
  }
}

// Helper function to calculate Pearson correlation coefficient
function calculateCorrelation(x: number[], y: number[]): number {
  const n = x.length;
  let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
  
  for (let i = 0; i < n; i++) {
    sumX += x[i];
    sumY += y[i];
    sumXY += x[i] * y[i];
    sumX2 += x[i] * x[i];
    sumY2 += y[i] * y[i];
  }
  
  const numerator = n * sumXY - sumX * sumY;
  const denominator = Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
  
  if (denominator === 0) return 0;
  return numerator / denominator;
}

// Helper function to estimate p-value (simplified)
function estimatePValue(correlation: number, n: number): number {
  // This is a simplified approximation
  // For a proper implementation, use a statistical library
  const t = correlation * Math.sqrt((n - 2) / (1 - correlation * correlation));
  // Simplified p-value estimation
  return 2 * (1 - Math.min(1, Math.abs(t) / 10));
}

// Example function (equivalent to on_request_example)
export const onRequestExample = functions.https.onCall(
  (request: CallableRequest<any>) => {
    return "Hello world!";
  }
);

// Submit feedback function - CONVERTED TO CALLABLE
export const submitFeedback = functions.https.onCall(
  async (request: CallableRequest<any>) => {
    const data = request.data;
    const context = request.auth;
    
    logger.info("submitFeedback called with data:", data);
    
    // Verify authentication
    if (!context) {
      logger.warn("Authentication failed");
      throw new functions.https.HttpsError(
        'unauthenticated', 
        'The function must be called while authenticated.'
      );
    }
    
    const userId = context.uid;
    logger.info("User authenticated:", userId);
    
    // Validate the data
    const { validatedData, error: validationError } = validateFeedbackData(data);
    if (validationError) {
      logger.warn("Validation error:", validationError);
      throw new functions.https.HttpsError('invalid-argument', validationError);
    }
    
    logger.info("Data validated successfully");
    
    // Query the pollen API using the provided location
    const lat = validatedData.location.lat;
    const lng = validatedData.location.lng;
    logger.info(`Getting pollen data for lat=${lat}, lng=${lng}`);
    
    const pollenData = await getPollenData(lat, lng);
    logger.info(`Retrieved ${pollenData.length} pollen data items`);
    
    // Store the feedback document, including the retrieved pollen data
    logger.info("Storing feedback in Firestore");
    const { docRef, error: storeError } = await storeFeedback(userId, validatedData, pollenData);
    if (storeError) {
      logger.error("Error storing feedback:", storeError);
      throw new functions.https.HttpsError('internal', storeError);
    }
    
    logger.info("Feedback stored successfully with ID:", docRef?.id);
    
    // Return the response
    return {
      success: true,
      documentId: docRef!.id,
      pollenData
    };
  }
);

// Get pollen analysis function - CONVERTED TO CALLABLE
export const getPollenAnalysis = functions.https.onCall(
  async (request: CallableRequest<any>) => {
    const context = request.auth;
    
    // Verify authentication
    if (!context) {
      throw new functions.https.HttpsError(
        'unauthenticated', 
        'The function must be called while authenticated.'
      );
    }
    
    const userId = context.uid;
    
    // Perform the correlation analysis
    const { result, error: analysisError } = await analyzePollenCorrelation(userId);
    if (analysisError) {
      throw new functions.https.HttpsError('internal', analysisError);
    }
    
    // Return the result
    return result;
  }
);
