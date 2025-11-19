#!/usr/bin/env node
/**
 * Agent Logger - Track agent-to-agent and user-to-agent communications
 * For JARVIS multi-agent system
 *
 * Usage in your agent:
 *   const { logAgentMessage, logAgentReceived } = require('./agent-logger');
 *
 *   // When sending a message to another agent:
 *   await logAgentMessage({
 *     from: 'agent-01-infrastructure',
 *     to: 'agent-08-database',
 *     message: 'Please create PostgreSQL database for WordPress',
 *     messageType: 'request',
 *     conversationId: 'conv-12345'
 *   });
 *
 *   // When receiving a message from user or another agent:
 *   await logAgentReceived({
 *     from: 'user' | 'agent-name',
 *     to: 'agent-01-infrastructure',
 *     message: 'Install WordPress on server',
 *     messageType: 'user-request' | 'agent-response' | 'agent-request'
 *   });
 */

const { createClient } = require('@supabase/supabase-js');

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jarvis-00.supabase.kithub.cloud';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzYzNDY4NDI1LCJleHAiOjE3OTUwMDQ0MjV9.B44hXPfVHj3YOciW7RrWhBOJqX8y2zRmJKdlIt-pQpg';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

/**
 * Log an agent message (outgoing or internal)
 *
 * @param {object} options
 * @param {string} options.from - Sender agent name
 * @param {string} options.to - Receiver agent name or 'user'
 * @param {string} options.message - Message content
 * @param {string} options.messageType - Type: 'request', 'response', 'delegation', 'user-request', 'user-response'
 * @param {string} options.conversationId - Conversation ID (optional, auto-generated if not provided)
 * @param {array} options.tags - Optional tags
 * @param {object} options.metadata - Optional metadata
 * @returns {object} { messageId, conversationId }
 */
async function logAgentMessage({
  from,
  to,
  message,
  messageType = 'request',
  conversationId = null,
  tags = [],
  metadata = {}
}) {
  // Generate IDs if not provided
  if (!conversationId) {
    conversationId = `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  const messageId = `msg-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

  try {
    const { data, error } = await supabase
      .from('agent_communications')
      .insert({
        message_id: messageId,
        timestamp: new Date().toISOString(),
        from_agent: from,
        to_agent: to,
        message: message,
        message_type: messageType,
        conversation_id: conversationId,
        status: 'sent',
        tags: [...tags, from, to, messageType],
        metadata: metadata
      })
      .select()
      .single();

    if (error) {
      console.warn('Agent Logger warning:', error.message);
    }

    return { messageId, conversationId };
  } catch (err) {
    console.warn('Agent Logger error:', err.message);
    return { messageId, conversationId };
  }
}

/**
 * Log received message (from user or another agent)
 * Same as logAgentMessage but semantically clearer for receiving
 *
 * @param {object} options - Same as logAgentMessage
 * @returns {object} { messageId, conversationId }
 */
async function logAgentReceived(options) {
  return logAgentMessage({
    ...options,
    status: 'received'
  });
}

/**
 * Update message status
 *
 * @param {string} messageId - Message ID to update
 * @param {string} status - New status: 'sent', 'received', 'processed', 'error'
 * @param {object} metadata - Optional additional metadata
 */
async function updateMessageStatus(messageId, status, metadata = {}) {
  try {
    const { error } = await supabase
      .from('agent_communications')
      .update({
        status: status,
        metadata: metadata,
        updated_at: new Date().toISOString()
      })
      .eq('message_id', messageId);

    if (error) {
      console.warn('Agent Logger warning:', error.message);
    }
  } catch (err) {
    console.warn('Agent Logger error:', err.message);
  }
}

/**
 * Log agent error
 *
 * @param {string} agentName - Agent name
 * @param {Error|string} error - Error object or message
 * @param {string} context - Error context (what was the agent doing)
 * @param {object} metadata - Optional metadata
 */
async function logAgentError(agentName, error, context = '', metadata = {}) {
  const errorMessage = error instanceof Error ? error.message : String(error);
  const errorStack = error instanceof Error ? error.stack : null;

  try {
    await supabase
      .from('agent_communications')
      .insert({
        message_id: `err-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        timestamp: new Date().toISOString(),
        from_agent: agentName,
        to_agent: 'system',
        message: `Error: ${errorMessage}`,
        message_type: 'error',
        status: 'error',
        tags: ['error', agentName],
        metadata: {
          ...metadata,
          context: context,
          error_stack: errorStack
        }
      });
  } catch (err) {
    console.warn('Agent Logger error:', err.message);
  }
}

/**
 * Get conversation history
 *
 * @param {string} conversationId - Conversation ID
 * @returns {array} Messages in conversation, ordered by timestamp
 */
async function getConversation(conversationId) {
  try {
    const { data, error } = await supabase
      .from('agent_communications')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('timestamp', { ascending: true });

    if (error) {
      console.error('Error getting conversation:', error);
      return [];
    }

    return data;
  } catch (err) {
    console.error('Error getting conversation:', err.message);
    return [];
  }
}

/**
 * Query agent messages
 *
 * @param {object} filters
 * @param {string} filters.fromAgent - Filter by sender agent
 * @param {string} filters.toAgent - Filter by receiver agent
 * @param {string} filters.messageType - Filter by message type
 * @param {string} filters.status - Filter by status
 * @param {number} filters.limit - Max results (default: 100)
 * @returns {array} Agent communication logs
 */
async function queryAgentMessages(filters = {}) {
  let query = supabase
    .from('agent_communications')
    .select('*')
    .order('timestamp', { ascending: false });

  if (filters.fromAgent) {
    query = query.eq('from_agent', filters.fromAgent);
  }

  if (filters.toAgent) {
    query = query.eq('to_agent', filters.toAgent);
  }

  if (filters.messageType) {
    query = query.eq('message_type', filters.messageType);
  }

  if (filters.status) {
    query = query.eq('status', filters.status);
  }

  const limit = filters.limit || 100;
  query = query.limit(limit);

  const { data, error } = await query;

  if (error) {
    console.error('Error querying agent messages:', error);
    return [];
  }

  return data;
}

/**
 * Get agent statistics
 *
 * @param {string} agentName - Agent name (optional, all agents if not provided)
 * @returns {object} Statistics
 */
async function getAgentStats(agentName = null) {
  let query = supabase
    .from('agent_communications')
    .select('from_agent, to_agent, message_type, status');

  if (agentName) {
    query = query.or(`from_agent.eq.${agentName},to_agent.eq.${agentName}`);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Error getting agent stats:', error);
    return null;
  }

  const stats = {
    total_messages: data.length,
    by_agent: {},
    by_type: {},
    by_status: {},
    sent: 0,
    received: 0
  };

  data.forEach(msg => {
    // By agent (sent)
    if (msg.from_agent) {
      if (!stats.by_agent[msg.from_agent]) {
        stats.by_agent[msg.from_agent] = { sent: 0, received: 0 };
      }
      stats.by_agent[msg.from_agent].sent++;
      stats.sent++;
    }

    // By agent (received)
    if (msg.to_agent) {
      if (!stats.by_agent[msg.to_agent]) {
        stats.by_agent[msg.to_agent] = { sent: 0, received: 0 };
      }
      stats.by_agent[msg.to_agent].received++;
      stats.received++;
    }

    // By type
    if (!stats.by_type[msg.message_type]) {
      stats.by_type[msg.message_type] = 0;
    }
    stats.by_type[msg.message_type]++;

    // By status
    if (!stats.by_status[msg.status]) {
      stats.by_status[msg.status] = 0;
    }
    stats.by_status[msg.status]++;
  });

  return stats;
}

module.exports = {
  logAgentMessage,
  logAgentReceived,
  updateMessageStatus,
  logAgentError,
  getConversation,
  queryAgentMessages,
  getAgentStats
};
