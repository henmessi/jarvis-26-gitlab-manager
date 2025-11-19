#!/usr/bin/env node
/**
 * Supabase Client for Agent 00
 * גישה ישירה ל-Supabase Database
 */

// Configuration - Auto-configured! Stored in Vault: secret/category-08/jarvis-00
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jarvis-00.supabase.kithub.cloud';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzYzNDY4NDI1LCJleHAiOjE3OTUwMDQ0MjV9.B44hXPfVHj3YOciW7RrWhBOJqX8y2zRmJKdlIt-pQpg';

// Install: npm install @supabase/supabase-js
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Helper Functions

/**
 * יצירת טבלה חדשה
 */
async function createTable(tableName, schema) {
  console.log(`Creating table: ${tableName}`);

  const { data, error } = await supabase.rpc('exec_sql', {
    sql: schema
  });

  if (error) {
    console.error('Error creating table:', error);
    return false;
  }

  console.log(`✅ Table ${tableName} created successfully`);
  return true;
}

/**
 * הוספת רשומה
 */
async function insertRecord(tableName, record) {
  const { data, error } = await supabase
    .from(tableName)
    .insert(record)
    .select();

  if (error) {
    console.error('Error inserting:', error);
    return null;
  }

  console.log(`✅ Record inserted:`, data);
  return data;
}

/**
 * קריאת רשומות
 */
async function queryRecords(tableName, filters = {}) {
  let query = supabase.from(tableName).select('*');

  // Apply filters
  Object.entries(filters).forEach(([key, value]) => {
    query = query.eq(key, value);
  });

  const { data, error } = await query;

  if (error) {
    console.error('Error querying:', error);
    return [];
  }

  return data;
}

/**
 * עדכון רשומה
 */
async function updateRecord(tableName, id, updates) {
  const { data, error } = await supabase
    .from(tableName)
    .update(updates)
    .eq('id', id)
    .select();

  if (error) {
    console.error('Error updating:', error);
    return null;
  }

  console.log(`✅ Record updated:`, data);
  return data;
}

/**
 * מחיקת רשומה
 */
async function deleteRecord(tableName, id) {
  const { error } = await supabase
    .from(tableName)
    .delete()
    .eq('id', id);

  if (error) {
    console.error('Error deleting:', error);
    return false;
  }

  console.log(`✅ Record deleted from ${tableName}`);
  return true;
}

/**
 * ריצת SQL ישירות (למנהלים בלבד)
 */
async function executeSql(sql) {
  const { data, error } = await supabase.rpc('exec_sql', { sql });

  if (error) {
    console.error('SQL Error:', error);
    return null;
  }

  return data;
}

// Examples

async function exampleUsage() {
  console.log('='.repeat(50));
  console.log('  Supabase Client for Agent 00');
  console.log('='.repeat(50));
  console.log();

  // דוגמה 1: יצירת משימה
  console.log('📝 Example 1: Create Task');
  const task = await insertRecord('tasks', {
    category_id: '00',
    agent_name: 'agent-orchestration',
    task_type: 'example',
    status: 'pending',
    priority: 5,
    payload: { message: 'Test task from Agent 00' }
  });

  // דוגמה 2: קריאת משימות
  console.log('\n📖 Example 2: Query Tasks');
  const tasks = await queryRecords('tasks', {
    category_id: '00',
    status: 'pending'
  });
  console.log(`Found ${tasks.length} pending tasks`);

  // דוגמה 3: עדכון משימה
  if (task && task[0]) {
    console.log('\n✏️  Example 3: Update Task');
    await updateRecord('tasks', task[0].id, {
      status: 'completed',
      result: { success: true, message: 'Task completed' }
    });
  }

  // דוגמה 4: QA Report
  console.log('\n📊 Example 4: Create QA Report');
  await insertRecord('qa_reports', {
    task_id: task?.[0]?.id,
    category_id: '00',
    report_type: 'system_check',
    findings: {
      vault_status: 'healthy',
      mcp_servers: 7,
      plugins: 11
    },
    recommendations: [
      'All systems operational',
      'No critical issues found'
    ],
    severity: 'info'
  });

  console.log('\n✅ All examples completed!');
}

// ================================================================
// AGENT COMMUNICATION LOGGING FUNCTIONS
// ================================================================

/**
 * תיעוד הודעה בין סוכנים
 */
async function logAgentCommunication({
  sourceAgent,
  targetAgent,
  conversationId,
  messageType = 'request',
  payload,
  result = null,
  status = 'sent',
  durationMs = null,
  errorMessage = null,
  context = null,
  tags = []
}) {
  const messageId = `msg-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

  const { data, error } = await supabase
    .from('agent_communications')
    .insert({
      source_agent: sourceAgent,
      target_agent: targetAgent,
      conversation_id: conversationId,
      message_id: messageId,
      message_type: messageType,
      payload,
      result,
      status,
      duration_ms: durationMs,
      error_message: errorMessage,
      context,
      tags
    })
    .select()
    .single();

  if (error) {
    console.error('Error logging communication:', error);
    return null;
  }

  // שליחה גם ל-Loki
  await sendToLoki({
    source_agent: sourceAgent,
    target_agent: targetAgent,
    message_type: messageType,
    status,
    ...data
  }).catch(err => console.warn('Loki warning:', err.message));

  return data;
}

/**
 * יצירת conversation חדש
 */
async function createConversation(initiator, participants, title = null) {
  const { data, error } = await supabase
    .rpc('create_conversation', {
      p_initiator: initiator,
      p_participants: participants,
      p_title: title
    });

  if (error) {
    console.error('Error creating conversation:', error);
    return null;
  }

  return data;
}

/**
 * שליחה ל-Loki
 */
async function sendToLoki(logData) {
  try {
    const lokiUrl = 'http://10.43.28.139:3100/loki/api/v1/push';

    const logEntry = {
      streams: [{
        stream: {
          job: "agent-communication",
          source_agent: logData.source_agent,
          target_agent: logData.target_agent,
          message_type: logData.message_type,
          status: logData.status,
          environment: "production"
        },
        values: [[
          String(Date.now() * 1000000), // nanoseconds
          JSON.stringify(logData)
        ]]
      }]
    };

    const response = await fetch(lokiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(logEntry)
    });

    if (!response.ok) {
      throw new Error(`Loki responded with ${response.status}`);
    }
  } catch (error) {
    // Don't fail if Loki is down, just log warning
    throw error;
  }
}

/**
 * שאילתת לוגים
 */
async function queryAgentLogs(filters = {}) {
  let query = supabase
    .from('agent_communications')
    .select('*')
    .order('timestamp', { ascending: false });

  if (filters.sourceAgent) {
    query = query.eq('source_agent', filters.sourceAgent);
  }
  if (filters.targetAgent) {
    query = query.eq('target_agent', filters.targetAgent);
  }
  if (filters.conversationId) {
    query = query.eq('conversation_id', filters.conversationId);
  }
  if (filters.status) {
    query = query.eq('status', filters.status);
  }
  if (filters.messageType) {
    query = query.eq('message_type', filters.messageType);
  }
  if (filters.limit) {
    query = query.limit(filters.limit);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Error querying logs:', error);
    return [];
  }

  return data;
}

/**
 * סטטיסטיקות סוכן
 */
async function getAgentStats(agentId) {
  const { data, error } = await supabase
    .from('agent_stats')
    .select('*')
    .eq('agent_id', agentId)
    .single();

  if (error && error.code !== 'PGRST116') { // Not found is OK
    console.error('Error getting agent stats:', error);
    return null;
  }

  return data;
}

/**
 * כל הסטטיסטיקות
 */
async function getAllAgentStats() {
  const { data, error } = await supabase
    .from('agent_stats')
    .select('*')
    .order('total_messages_sent', { ascending: false });

  if (error) {
    console.error('Error getting all stats:', error);
    return [];
  }

  return data;
}

// Export functions
module.exports = {
  supabase,
  createTable,
  insertRecord,
  queryRecords,
  updateRecord,
  deleteRecord,
  executeSql,
  // Logging functions
  logAgentCommunication,
  createConversation,
  queryAgentLogs,
  getAgentStats,
  getAllAgentStats,
  sendToLoki
};

// Run examples if called directly
if (require.main === module) {
  exampleUsage().catch(console.error);
}