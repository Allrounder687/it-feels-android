export async function handleOpenAIAction(apiKey: string, action: string, payload: any) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${apiKey}`
  };

  const messages = buildMessages(action, payload);
  const responseFormat = buildResponseFormat(action);

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model: 'gpt-5.6-luna',
      messages,
      ...(responseFormat ? { response_format: responseFormat } : {})
    })
  });

  const data: any = await res.json();
  if (!res.ok) throw new Error(data.error?.message || 'OpenAI API error');
  
  const content = data.choices[0].message.content;
  if (responseFormat) {
    return JSON.parse(content);
  }
  return content;
}

export async function handleClaudeAction(apiKey: string, action: string, payload: any) {
  const headers = {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01'
  };

  const messages = buildMessages(action, payload);
  const systemMessage = messages.find(m => m.role === 'system')?.content || '';
  const userMessages = messages.filter(m => m.role !== 'system');

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      system: systemMessage,
      messages: userMessages
    })
  });

  const data: any = await res.json();
  if (!res.ok) throw new Error(data.error?.message || 'Claude API error');
  
  let content = data.content[0].text;
  
  // Basic JSON extraction if expected
  if (buildResponseFormat(action)) {
    try {
      const match = content.match(/\{[\s\S]*\}/);
      if (match) content = match[0];
      return JSON.parse(content);
    } catch(e) {
      return { playlist: [] }; // Fallback
    }
  }
  return content;
}

export async function handleGeminiAction(apiKey: string, action: string, payload: any) {
  const headers = {
    'Content-Type': 'application/json'
  };

  const messages = buildMessages(action, payload);
  const systemText = messages.find(m => m.role === 'system')?.content || '';
  const userText = messages.find(m => m.role === 'user')?.content || '';
  
  const prompt = `${systemText}\n\n${userText}`;
  const responseFormat = buildResponseFormat(action);

  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      ...(responseFormat ? { generationConfig: { responseMimeType: 'application/json' } } : {})
    })
  });

  const data: any = await res.json();
  if (!res.ok) throw new Error(data.error?.message || 'Gemini API error');
  
  let content = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
  
  if (responseFormat) {
    try {
      return JSON.parse(content);
    } catch(e) {
      return { playlist: [] };
    }
  }
  return content;
}

function buildMessages(action: string, payload: any): { role: string, content: string }[] {
  switch (action) {
    case 'generatePlaylistFromRequest':
      return [
        { role: 'system', content: 'You are an intelligent music DJ. From the available library, output a playlist matching the user request. Return only the JSON schema: {"playlist": ["Song Title"]}' },
        { role: 'user', content: `Request: "${payload.userRequest}"\n\nLibrary:\n${JSON.stringify(payload.libraryMetadata)}` }
      ];
    case 'generateGlobalPlaylistNames':
      return [
        { role: 'system', content: 'You are an intelligent music DJ. Recommend exactly 10 highly relevant songs from across all global music. Return only the JSON schema: {"playlist": ["Song Title"]}' },
        { role: 'user', content: `Request: "${payload.userRequest}"` }
      ];
    case 'reorderQueueByMood':
      return [
        { role: 'system', content: 'Reorder the queue to match the mood. Do not add new songs. Return JSON schema: {"playlist": ["Song Title"]}' },
        { role: 'user', content: `Mood: "${payload.moodDescription}"\n\nQueue:\n${JSON.stringify(payload.queueMetadata)}` }
      ];
    case 'suggestPlaylistName':
      return [
        { role: 'system', content: 'Suggest a creative name for this playlist. Return JSON schema: {"name": "Creative Name"}' },
        { role: 'user', content: `Initial Name: "${payload.initialName}"\n\nSongs:\n${JSON.stringify(payload.songsMetadata)}` }
      ];
    case 'describePlaylistVibe':
      return [
        { role: 'system', content: 'Describe the vibe of this playlist in one short paragraph.' },
        { role: 'user', content: `Songs:\n${JSON.stringify(payload.songsMetadata)}` }
      ];
    case 'recommendSongs':
      return [
        { role: 'system', content: 'Recommend 5 songs based on this context. Return JSON schema: {"playlist": ["Song Title"]}' },
        { role: 'user', content: `Context: "${payload.context}"\n\nLibrary:\n${JSON.stringify(payload.libraryMetadata)}` }
      ];
    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

function buildResponseFormat(action: string): any {
  if (['generatePlaylistFromRequest', 'generateGlobalPlaylistNames', 'reorderQueueByMood', 'recommendSongs'].includes(action)) {
    return {
      type: 'json_schema',
      json_schema: {
        name: 'playlist_schema',
        strict: true,
        schema: {
          type: 'object',
          properties: { playlist: { type: 'array', items: { type: 'string' } } },
          required: ['playlist'],
          additionalProperties: false
        }
      }
    };
  } else if (action === 'suggestPlaylistName') {
    return {
      type: 'json_schema',
      json_schema: {
        name: 'name_schema',
        strict: true,
        schema: {
          type: 'object',
          properties: { name: { type: 'string' } },
          required: ['name'],
          additionalProperties: false
        }
      }
    };
  }
  return null; // return raw text for describePlaylistVibe
}
