import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { processData, evidences, defenses } = await req.json();
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    
    if (!LOVABLE_API_KEY) {
      throw new Error("LOVABLE_API_KEY não configurada");
    }

    const systemPrompt = `Você é um assistente jurídico especializado em análise de processos judiciais brasileiros. 
    Sua função é auxiliar juízes na análise de processos, fornecendo sugestões fundamentadas em lei.
    
    Analise o processo apresentado considerando:
    - Descrição do processo
    - Provas apresentadas
    - Defesas dos representantes
    - Legislação brasileira aplicável
    
    Forneça uma análise objetiva e sugestões de julgamento, sempre fundamentadas em lei.`;

    const userPrompt = `Analise o seguinte processo:
    
    Título: ${processData.title}
    Descrição: ${processData.description}
    Tipo de Processo: ${processData.judge_type}
    
    Provas Apresentadas:
    ${evidences.map((e: any, i: number) => `${i + 1}. ${e.file_name} (${e.file_type})`).join('\n')}
    
    Defesas:
    ${defenses.map((d: any, i: number) => `${i + 1}. ${d.defense_text}`).join('\n\n')}
    
    Forneça uma análise completa e sugestão de julgamento.`;

    const response = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LOVABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "google/gemini-2.5-flash",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
      }),
    });

    if (!response.ok) {
      if (response.status === 429) {
        return new Response(
          JSON.stringify({ error: "Limite de uso excedido. Tente novamente mais tarde." }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (response.status === 402) {
        return new Response(
          JSON.stringify({ error: "Créditos insuficientes. Adicione créditos em Settings -> Workspace -> Usage." }),
          { status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const errorText = await response.text();
      console.error("Erro na API da IA:", response.status, errorText);
      throw new Error("Erro ao chamar a API da IA");
    }

    const data = await response.json();
    const suggestion = data.choices[0].message.content;

    return new Response(
      JSON.stringify({ suggestion }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Erro em judge-ai-assistant:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Erro desconhecido' }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
