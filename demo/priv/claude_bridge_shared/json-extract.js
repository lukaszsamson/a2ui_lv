"use strict";
/**
 * JSON Extraction Utilities
 *
 * Functions to extract JSON from LLM responses that may contain
 * markdown code blocks or other formatting.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractJson = extractJson;
exports.extractJsonObject = extractJsonObject;
/**
 * Parse the raw LLM response and extract A2UI JSON.
 */
function extractJson(response) {
    let str = response.trim();
    // Remove any leading/trailing whitespace
    str = str.replace(/^\s+|\s+$/g, "");
    // If it starts with JSON, extract the complete object
    if (str.startsWith("{")) {
        return extractJsonObject(str);
    }
    // Extract from ```json block
    const jsonBlockMatch = str.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonBlockMatch) {
        return extractJsonObject(jsonBlockMatch[1].trim());
    }
    // Extract from ``` block
    const codeBlockMatch = str.match(/```\s*([\s\S]*?)\s*```/);
    if (codeBlockMatch) {
        return extractJsonObject(codeBlockMatch[1].trim());
    }
    // Find first { and extract from there
    const firstBrace = str.indexOf("{");
    if (firstBrace !== -1) {
        return extractJsonObject(str.substring(firstBrace));
    }
    return str;
}
/**
 * Extract a complete JSON object from a string that starts with {
 */
function extractJsonObject(str) {
    if (!str.startsWith("{")) {
        return str;
    }
    let depth = 0;
    let inString = false;
    let escape = false;
    for (let i = 0; i < str.length; i++) {
        const char = str[i];
        if (escape) {
            escape = false;
            continue;
        }
        if (char === "\\") {
            escape = true;
            continue;
        }
        if (char === '"') {
            inString = !inString;
            continue;
        }
        if (inString)
            continue;
        if (char === "{") {
            depth++;
        }
        else if (char === "}") {
            depth--;
            if (depth === 0) {
                return str.substring(0, i + 1);
            }
        }
    }
    return str;
}
