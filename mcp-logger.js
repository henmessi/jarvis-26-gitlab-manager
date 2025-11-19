#!/usr/bin/env node
/**
 * MCP Logger - Track MCP plugin internal operations
 * For JARVIS multi-agent system
 *
 * Usage in MCP servers:
 *   const { logMCPToolCall, completeMCPToolCall } = require('./mcp-logger');
 *
 *   // When starting a tool call:
 *   const callId = await logMCPToolCall({
 *     mcpServer: 'vault',
 *     toolName: 'kv-get',
 *     requestingAgent: 'agent-01-infrastructure',
 *     inputParams: { path: 'secret/db' },
 *     conversationId: 'conv-12345',  // optional, link to agent conversation
 *     messageId: 'msg-67890'          // optional, link to specific agent message
 *   });
 *
 *   // When tool completes:
 *   await completeMCPToolCall(callId, {
 *     outputResult: { value: '***' },
 *     status: 'success'
 *   });
 */

const { createClient } = require('@supabase/supabase-js');

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jarvis-00.supabase.kithub.cloud';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzYzNDY4NDI1LCJleHAiOjE3OTUwMDQ0MjV9.B44hXPfVHj3YOciW7RrWhBOJqX8y2zRmJKdlIt-pQpg';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

/**
 * Log MCP tool call
 *
 * @param {object} options
 * @param {string} options.mcpServer - MCP server name (e.g., 'vault', 'perplexity')
 * @param {string} options.toolName - Tool name within MCP server
 * @param {string} options.requestingAgent - Which agent requested this
 * @param {object} options.inputParams - Tool input parameters
 * @param {string} options.conversationId - Optional link to agent conversation
 * @param {string} options.messageId - Optional link to agent message
 * @param {array} options.tags - Optional tags
 * @returns {string} Call ID
 */
async function logMCPToolCall({
  mcpServer,
  toolName,
  requestingAgent,
  inputParams,
  conversationId = null,
  messageId = null,
  tags = []
}) {
  const callId = `mcp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

  try {
    const { data, error } = await supabase
      .from('mcp_tool_calls')
      .insert({
        id: callId,
        timestamp: new Date().toISOString(),
        mcp_server: mcpServer,
        tool_name: toolName,
        requesting_agent: requestingAgent,
        conversation_id: conversationId,
        message_id: messageId,
        input_params: inputParams,
        status: 'running',
        tags: [...tags, mcpServer, toolName, requestingAgent]
      })
      .select()
      .single();

    if (error) {
      console.warn('MCP Logger warning:', error.message);
    }

    return callId;
  } catch (err) {
    console.warn('MCP Logger error:', err.message);
    return callId;
  }
}

/**
 * Complete MCP tool call and calculate execution time
 *
 * @param {string} callId - Call ID to complete
 * @param {object} options
 * @param {object} options.outputResult - Tool output result
 * @param {string} options.status - 'success' or 'error'
 * @param {string} options.errorMessage - Error message if failed
 * @returns {number} Execution time in milliseconds
 */
async function completeMCPToolCall(callId, {
  outputResult = null,
  status = 'success',
  errorMessage = null
}) {
  try {
    // Get original call to calculate duration
    const { data: original, error: fetchError } = await supabase
      .from('mcp_tool_calls')
      .select('timestamp')
      .eq('id', callId)
      .single();

    if (fetchError) {
      console.warn('MCP Logger warning:', fetchError.message);
      return null;
    }

    const startTime = new Date(original.timestamp);
    const endTime = new Date();
    const executionTimeMs = endTime - startTime;

    // Update with completion info
    const { error } = await supabase
      .from('mcp_tool_calls')
      .update({
        output_result: outputResult,
        execution_time_ms: executionTimeMs,
        status: status,
        error_message: errorMessage
      })
      .eq('id', callId);

    if (error) {
      console.warn('MCP Logger warning:', error.message);
    }

    return executionTimeMs;
  } catch (err) {
    console.warn('MCP Logger error:', err.message);
    return null;
  }
}

/**
 * Log MCP tool error
 *
 * @param {string} callId - Call ID
 * @param {Error|string} error - Error object or message
 */
async function logMCPToolError(callId, error) {
  const errorMessage = error instanceof Error ? error.message : String(error);
  const errorStack = error instanceof Error ? error.stack : null;

  try {
    await supabase
      .from('mcp_tool_calls')
      .update({
        status: 'error',
        error_message: errorMessage,
        output_result: { error_stack: errorStack }
      })
      .eq('id', callId);
  } catch (err) {
    console.warn('MCP Logger error:', err.message);
  }
}

/**
 * Query MCP tool calls
 *
 * @param {object} filters
 * @param {string} filters.mcpServer - Filter by MCP server
 * @param {string} filters.toolName - Filter by tool name
 * @param {string} filters.requestingAgent - Filter by requesting agent
 * @param {string} filters.conversationId - Filter by conversation
 * @param {string} filters.status - Filter by status
 * @param {number} filters.limit - Max results (default: 100)
 * @returns {array} MCP tool call logs
 */
async function queryMCPToolCalls(filters = {}) {
  let query = supabase
    .from('mcp_tool_calls')
    .select('*')
    .order('timestamp', { ascending: false });

  if (filters.mcpServer) {
    query = query.eq('mcp_server', filters.mcpServer);
  }

  if (filters.toolName) {
    query = query.eq('tool_name', filters.toolName);
  }

  if (filters.requestingAgent) {
    query = query.eq('requesting_agent', filters.requestingAgent);
  }

  if (filters.conversationId) {
    query = query.eq('conversation_id', filters.conversationId);
  }

  if (filters.status) {
    query = query.eq('status', filters.status);
  }

  const limit = filters.limit || 100;
  query = query.limit(limit);

  const { data, error } = await query;

  if (error) {
    console.error('Error querying MCP tool calls:', error);
    return [];
  }

  return data;
}

/**
 * Get MCP server statistics
 *
 * @param {string} mcpServer - MCP server name (optional, all if not provided)
 * @returns {object} Statistics
 */
async function getMCPStats(mcpServer = null) {
  let query = supabase
    .from('mcp_tool_calls')
    .select('mcp_server, tool_name, status, execution_time_ms');

  if (mcpServer) {
    query = query.eq('mcp_server', mcpServer);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Error getting MCP stats:', error);
    return null;
  }

  const stats = {
    total_calls: data.length,
    by_server: {},
    by_tool: {},
    by_status: {},
    avg_execution_time: 0,
    total_execution_time: 0
  };

  let totalTime = 0;
  let countWithTime = 0;

  data.forEach(call => {
    // By server
    if (!stats.by_server[call.mcp_server]) {
      stats.by_server[call.mcp_server] = { count: 0, avg_time: 0 };
    }
    stats.by_server[call.mcp_server].count++;

    // By tool
    const toolKey = `${call.mcp_server}/${call.tool_name}`;
    if (!stats.by_tool[toolKey]) {
      stats.by_tool[toolKey] = { count: 0, avg_time: 0 };
    }
    stats.by_tool[toolKey].count++;

    // By status
    if (!stats.by_status[call.status]) {
      stats.by_status[call.status] = 0;
    }
    stats.by_status[call.status]++;

    // Execution time
    if (call.execution_time_ms) {
      totalTime += call.execution_time_ms;
      countWithTime++;
    }
  });

  stats.avg_execution_time = countWithTime > 0 ? Math.round(totalTime / countWithTime) : 0;
  stats.total_execution_time = totalTime;

  return stats;
}

/**
 * Get tool calls for a conversation
 *
 * @param {string} conversationId - Conversation ID
 * @returns {array} MCP tool calls in conversation
 */
async function getMCPCallsForConversation(conversationId) {
  try {
    const { data, error } = await supabase
      .from('mcp_tool_calls')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('timestamp', { ascending: true });

    if (error) {
      console.error('Error getting MCP calls for conversation:', error);
      return [];
    }

    return data;
  } catch (err) {
    console.error('Error getting MCP calls for conversation:', err.message);
    return [];
  }
}

module.exports = {
  logMCPToolCall,
  completeMCPToolCall,
  logMCPToolError,
  queryMCPToolCalls,
  getMCPStats,
  getMCPCallsForConversation
};
