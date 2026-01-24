"use strict";
/**
 * A2UI Claude Bridge Shared Module
 *
 * Common utilities shared between ZMQ and HTTP+SSE bridge implementations.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseActionRequest = exports.isActionRequest = exports.buildDataModelUpdateMessages = exports.buildA2uiMessages = exports.extractJsonObject = exports.extractJson = exports.A2UI_ACTION_PROMPT = exports.A2UI_SYSTEM_PROMPT = void 0;
var prompts_1 = require("./prompts");
Object.defineProperty(exports, "A2UI_SYSTEM_PROMPT", { enumerable: true, get: function () { return prompts_1.A2UI_SYSTEM_PROMPT; } });
Object.defineProperty(exports, "A2UI_ACTION_PROMPT", { enumerable: true, get: function () { return prompts_1.A2UI_ACTION_PROMPT; } });
var json_extract_1 = require("./json-extract");
Object.defineProperty(exports, "extractJson", { enumerable: true, get: function () { return json_extract_1.extractJson; } });
Object.defineProperty(exports, "extractJsonObject", { enumerable: true, get: function () { return json_extract_1.extractJsonObject; } });
var a2ui_builder_1 = require("./a2ui-builder");
Object.defineProperty(exports, "buildA2uiMessages", { enumerable: true, get: function () { return a2ui_builder_1.buildA2uiMessages; } });
Object.defineProperty(exports, "buildDataModelUpdateMessages", { enumerable: true, get: function () { return a2ui_builder_1.buildDataModelUpdateMessages; } });
Object.defineProperty(exports, "isActionRequest", { enumerable: true, get: function () { return a2ui_builder_1.isActionRequest; } });
Object.defineProperty(exports, "parseActionRequest", { enumerable: true, get: function () { return a2ui_builder_1.parseActionRequest; } });
