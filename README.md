# Nexus — cérebro inicial

Backend inicial do Nexus para Cloudflare Workers, com memória de conversas no Supabase e respostas por API da OpenAI.

## O que esta versão faz

- `GET /health`: verifica se o Worker está publicado.
- `POST /v1/chat`: recebe uma mensagem autenticada, recupera as últimas 12 mensagens do mesmo usuário, consulta o modelo configurado e grava pergunta e resposta no Supabase.
- Segredos ficam nas configurações do Cloudflare, nunca neste repositório.

> Esta é uma primeira memória de conversa por histórico recente. Ainda não é memória semântica/embeddings, não aprende nem treina o modelo, e não substitui autenticação de usuários no site.

## 1. Banco Supabase

1. Crie um projeto no Supabase.
2. Abra **SQL Editor** e execute o arquivo `schema.sql`.
3. Em **Project Settings → API**, copie a URL do projeto e a chave `service_role`. Nunca coloque a chave `service_role` no site ou em código público.

## 2. Publicar no Cloudflare Workers

1. Abra https://dash.cloudflare.com/ e entre/crie sua conta.
2. Vá em **Workers & Pages** e crie um Worker.
3. Para publicar pelo GitHub, conecte este repositório e escolha a branch `feat/nexus-worker-foundation` (ou use Wrangler localmente).
4. Configure os secrets/variáveis no Worker:
   - `SUPABASE_ANON_KEY`: chave pública/anon do projeto, usada apenas para validar a sessão do usuário.
   - `OPENAI_API_KEY`: chave de API do provedor OpenAI.
   - `SUPABASE_URL`: URL do projeto Supabase.
   - `SUPABASE_SERVICE_ROLE_KEY`: chave service_role do Supabase.
   - `OPENAI_MODEL`: opcional; padrão `gpt-4.1-mini`.
   - `NEXUS_SYSTEM_PROMPT`: opcional; instruções de personalidade do Nexus.
   - `ALLOWED_ORIGIN`: opcional; domínio exato do site que chamará o Worker.
5. Publique e teste `https://SEU-WORKER.workers.dev/health`.

## 3. Chamada de chat

Envie um POST para `https://SEU-WORKER.workers.dev/v1/chat` com:

Headers:
- `Authorization: Bearer TOKEN_DE_ACESSO_SUPABASE` (sessão do usuário autenticado)
- `Content-Type: application/json`

Body:
```json
{
  "message": "Olá, Nexus!"
}
```

Resposta:
```json
{ "answer": "Olá! Como posso ajudar?", "model": "gpt-4.1-mini" }
```

O site deve permitir que o usuário entre pelo Supabase Auth e enviar o access token da sessão no cabeçalho Authorization. O Worker valida esse token no Supabase e obtém o ID real da conta; o navegador não escolhe o userId. Nunca exponha a chave service_role ou a chave OpenAI no JavaScript público. A chave anon pode estar no cliente conforme o padrão do Supabase, desde que RLS esteja configurado corretamente.

## Custos e limites

Cloudflare, Supabase e o provedor de IA têm limites e planos próprios. A API de IA pode gerar cobrança separada; confira preços e limites antes de adicionar créditos.

## Próximas etapas

- Conectar o site Nexus a `/v1/chat`.
- Implementar login real e associar cada memória à conta autenticada.
- Adicionar controles para consultar, exportar e apagar memórias.
- Avaliar memória de longo prazo por busca semântica, com consentimento do usuário.


## Plataforma Nexus — primeira etapa (19/11/2026)

A branch `feat/nexus-platform-foundation` adiciona a base inicial de contas e uso:

- Perfil individual por conta Supabase Auth.
- Plano inicial `free` com 100 créditos por mês.
- Um crédito é consumido por mensagem enviada ao chat (mensagens de aprendizagem/guardar conhecimento não consomem crédito nesta etapa).
- Endpoint autenticado `GET /v1/account` para consultar plano e saldo.
- Painel no site mostrando plano e créditos disponíveis.
- O Worker impede novas mensagens quando o saldo chega a zero.

### Ativação obrigatória no Supabase

Antes de publicar esta branch no Worker, abra o SQL Editor do projeto Supabase e execute o arquivo:

`supabase/migrations/20261119_nexus_accounts_credits.sql`

A migração cria os perfis, preenche perfis para contas existentes e instala a função segura de consumo de créditos. A chave `SUPABASE_SERVICE_ROLE_KEY` continua somente como secret no Cloudflare Worker.

### O que ainda não está ativado

Esta etapa não processa pagamentos reais nem vende planos. Os planos Pro e Empresarial aparecem apenas como estrutura futura; não altere manualmente o plano para liberar recursos pagos. A próxima etapa exige escolher e configurar um provedor de pagamento, validar notificações/webhooks no servidor e só então ativar assinaturas. Nenhuma chave financeira deve ser colocada no navegador ou neste repositório.
