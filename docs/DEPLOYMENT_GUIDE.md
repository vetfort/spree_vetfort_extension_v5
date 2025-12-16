# AI Consultant Deployment Guide

## Overview

This guide covers the production deployment of the AI Shopping Consultant feature for the Spree VetFort Extension. The feature is ~85% complete with all core functionality implemented. This document focuses on the operational requirements for rollout.

## Prerequisites

Before deploying, ensure the following are ready:

### 1. OpenAI API Access
- [ ] OpenAI API account created at https://platform.openai.com/
- [ ] API key generated (starts with `sk-`)
- [ ] Billing configured and limits set
- [ ] Understand the pricing for GPT-4o-mini model:
  - Input: ~$0.15 per 1M tokens
  - Output: ~$0.60 per 1M tokens
  - Typical conversation: 1,000-3,000 tokens (~$0.001-0.003 per exchange)

### 2. WebSocket/Cable Infrastructure
- [ ] Production server supports WebSocket connections
- [ ] Load balancer/reverse proxy configured to allow WebSocket upgrades
- [ ] Solid Cable or Action Cable configured for real-time communication

### 3. Background Job Processor
- [ ] Solid Queue (recommended), Sidekiq, or Resque configured
- [ ] Worker processes running in production
- [ ] Job monitoring/alerting configured

### 4. Database
- [ ] PostgreSQL 12+ (for JSONB support) or SQLite 3.45+ 
- [ ] Database migrations ready to run

---

## Deployment Steps

### Step 1: Environment Configuration

#### Production Environment Variables

Add these to your production environment:

```bash
# Required
OPENAI_API_KEY=sk-proj-...your-key-here...

# Optional but recommended
OPENAI_MAX_TOKENS=1000                    # Limit response length
OPENAI_TEMPERATURE=0.3                     # Lower = more consistent
AI_CONSULTANT_RATE_LIMIT_PER_USER=20      # Requests per hour per user
AI_CONSULTANT_MAX_CONVERSATION_LENGTH=50   # Max messages in conversation
```

#### Verify Configuration

```bash
# On production server
rails runner "puts ENV['OPENAI_API_KEY'].present? ? 'API Key configured' : 'ERROR: Missing API key'"
```

### Step 2: Database Migrations

Run the migrations in production:

```bash
# Check pending migrations
rails db:migrate:status

# Run migrations
rails db:migrate

# Verify tables exist
rails runner "puts Spree::VetfortExtensionV5::AiConsultantMessage.table_exists? ? 'Tables created' : 'ERROR: Tables missing'"
```

Expected new tables:
- `ai_consultant_conversations`
- `ai_consultant_messages`

Expected new columns:
- `ai_consultant_messages.products` (JSONB)
- `ai_consultant_messages.raw_json` (TEXT)

### Step 3: WebSocket Configuration

#### For Nginx (common reverse proxy)

Add to your Nginx config:

```nginx
location /cable {
  proxy_pass http://app_server;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "Upgrade";
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_read_timeout 86400;
}
```

#### Verify WebSocket Connection

```bash
# Test from browser console after deployment
const ws = new WebSocket('wss://your-domain.com/cable');
ws.onopen = () => console.log('WebSocket connected!');
ws.onerror = (err) => console.error('WebSocket error:', err);
```

### Step 4: Background Job Configuration

#### Verify Queue is Running

```bash
# Check Solid Queue status
rails runner "puts SolidQueue::Job.count"

# Check workers are running
ps aux | grep solid_queue
```

#### Configure Worker Count

For production traffic, we recommend:
- 2-5 workers for AI chat jobs
- Monitor queue depth and adjust as needed

```bash
# In your process manager (systemd, Procfile, etc.)
solid_queue: bundle exec rake solid_queue:start WORKERS=3
```

### Step 5: Product Data Preparation

Ensure products have AI searchable tags:

```bash
# Audit existing products
rails runner "
  total = Spree::Product.count
  tagged = Spree::Product.tagged_with(
    ActsAsTaggableOn::Tag.where('name LIKE ?', 'ai_searchable:%'), 
    any: true
  ).count
  puts \"Products with AI tags: #{tagged}/#{total}\"
"
```

If products lack tags, bulk tag them:

```ruby
# Example: Tag all dog products
Spree::Product.where(name: /dog/i).each do |product|
  product.tag_list.add(AiSearchable::TagFormat.build('species', 'dog'))
  product.save
end
```

### Step 6: Smoke Test in Production

After deployment, test the full flow:

1. **Open AI Consultant**
   - Navigate to your store's homepage
   - Look for the AI consultant button/icon
   - Verify it opens without errors

2. **Send Test Message**
   ```
   User: "I need food for my senior dog with allergies"
   ```

3. **Verify Response**
   - Check that assistant responds within 5-10 seconds
   - Verify products are displayed in the grid
   - Verify product links work
   - Check that clicking a product navigates to product page

4. **Check Logs**
   ```bash
   # Watch logs during test
   tail -f log/production.log | grep -i "ai\|langchain"
   ```

5. **Verify Database**
   ```bash
   rails runner "
     conv = Spree::VetfortExtensionV5::AiConsultantConversation.last
     puts \"Conversation ID: #{conv.id}\"
     puts \"Messages: #{conv.messages.count}\"
     puts \"Products recommended: #{conv.messages.last.products.count}\"
   "
   ```

---

## Monitoring & Maintenance

### Key Metrics to Monitor

1. **API Usage**
   - OpenAI token consumption
   - API response time
   - Error rate
   - Cost per conversation

2. **System Performance**
   - Background job queue depth
   - Job processing time
   - WebSocket connection count
   - Database query performance

3. **User Experience**
   - Conversation completion rate
   - Average conversation length
   - Products clicked from recommendations
   - Conversion rate from AI recommendations

### Monitoring Setup

#### Application Performance Monitoring

```ruby
# Add to config/initializers/ai_consultant_monitoring.rb
ActiveSupport::Notifications.subscribe('ai_consultant.llm_call') do |name, start, finish, id, payload|
  duration = finish - start
  Rails.logger.info("[AI Consultant] LLM call took #{duration.round(2)}s, tokens: #{payload[:tokens]}")
  
  # Send to your monitoring service (DataDog, NewRelic, etc.)
  # StatsD.increment('ai_consultant.llm_calls')
  # StatsD.timing('ai_consultant.llm_duration', duration * 1000)
end
```

#### Cost Tracking

```ruby
# Track OpenAI costs
# config/initializers/openai_cost_tracker.rb
module OpenAICostTracker
  COST_PER_1M_INPUT_TOKENS = 0.15
  COST_PER_1M_OUTPUT_TOKENS = 0.60
  
  def self.track(input_tokens:, output_tokens:)
    cost = (input_tokens / 1_000_000.0 * COST_PER_1M_INPUT_TOKENS) +
           (output_tokens / 1_000_000.0 * COST_PER_1M_OUTPUT_TOKENS)
    
    Rails.logger.info("[AI Cost] Tokens: #{input_tokens + output_tokens}, Cost: $#{cost.round(4)}")
    # Send to monitoring service
  end
end
```

### Alert Configuration

Set up alerts for:

1. **High Error Rate**
   - Trigger: > 5% of AI requests fail
   - Action: Check OpenAI API status, verify API key, check network

2. **High Latency**
   - Trigger: Response time > 15 seconds
   - Action: Check background job queue, verify OpenAI API performance

3. **Cost Spike**
   - Trigger: Daily cost > 2x average
   - Action: Check for abuse, review conversation logs

4. **Queue Depth**
   - Trigger: > 100 jobs pending for > 5 minutes
   - Action: Scale up workers, check for stuck jobs

---

## Troubleshooting

### Issue: AI not responding

**Symptoms:** User sends message, but no response appears

**Diagnosis:**
```bash
# Check background jobs
rails runner "puts AiChatJob.where(created_at: 10.minutes.ago..).count"

# Check recent errors
tail -100 log/production.log | grep ERROR
```

**Common Causes:**
1. OpenAI API key not configured or invalid
2. Background job processor not running
3. WebSocket connection failed
4. Network timeout to OpenAI

**Fix:**
```bash
# Verify API key
rails runner "llm = Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY']); puts llm.chat(messages: [{role: 'user', content: 'test'}])"

# Restart workers
systemctl restart solid_queue
```

### Issue: Products not displaying

**Symptoms:** Text response shows, but products grid is empty

**Diagnosis:**
```bash
# Check if products have product_id field
rails runner "
  msg = Spree::VetfortExtensionV5::AiConsultantMessage.assistant.last
  puts msg.products.inspect
"
```

**Common Causes:**
1. LLM returning products without product_id
2. Product IDs don't exist in database
3. JSON parsing error

**Fix:**
- Review `raw_json` field in message record
- Verify product IDs exist in `spree_products`
- Check for JSON structure errors in logs

### Issue: High OpenAI costs

**Symptoms:** Unexpected high API bills

**Diagnosis:**
```bash
# Check conversation lengths
rails runner "
  avg = Spree::VetfortExtensionV5::AiConsultantConversation
    .joins(:messages)
    .group(:id)
    .count
    .values
    .sum / Spree::VetfortExtensionV5::AiConsultantConversation.count.to_f
  puts \"Average messages per conversation: #{avg.round(2)}\"
"
```

**Mitigation:**
1. Implement rate limiting per user
2. Set max conversation length
3. Add caching for common queries
4. Review system prompt length

---

## Rollback Plan

If critical issues occur, rollback procedure:

### 1. Disable Feature (Quick Fix)

```ruby
# config/initializers/ai_consultant_feature_flag.rb
Rails.application.config.ai_consultant_enabled = false
```

Then restart app servers. This hides the UI but preserves data.

### 2. Full Rollback (if needed)

```bash
# Revert to previous deployment
git revert <commit-hash>
bundle install
rails db:rollback STEP=2  # Rollback migrations if needed
```

### 3. Data Preservation

If rolling back, preserve conversation data for analysis:

```bash
# Export conversations before rollback
rails runner "
  File.write('ai_conversations_backup.json', 
    Spree::VetfortExtensionV5::AiConsultantConversation
      .includes(:messages)
      .to_json(include: :messages)
  )
"
```

---

## Security Considerations

### Input Validation

The current implementation includes:
- ✅ Message content validation in model
- ✅ Products structure validation
- ✅ JSON parsing with error handling

### Recommended Additional Security

1. **Rate Limiting**
   ```ruby
   # config/initializers/rack_attack.rb
   Rack::Attack.throttle('ai_consultant', limit: 20, period: 1.hour) do |req|
     req.ip if req.path == '/ai_conversations' && req.post?
   end
   ```

2. **Input Sanitization**
   - User messages are passed to LLM (OpenAI sanitizes)
   - HTML output is already escaped by Rails ERB

3. **API Key Protection**
   - ✅ Never commit API keys to git
   - ✅ Use encrypted credentials or env vars
   - ✅ Rotate keys periodically

---

## Cost Estimation

Based on typical usage:

| Metric | Estimate | Notes |
|--------|----------|-------|
| Average conversation | 4-6 messages | 2-3 exchanges |
| Tokens per exchange | 1,500 tokens | ~300 input + 200 output + context |
| Cost per conversation | $0.002 - $0.004 | Based on GPT-4o-mini pricing |
| 1,000 conversations/day | $2 - $4/day | ~$60-120/month |
| 10,000 conversations/day | $20 - $40/day | ~$600-1,200/month |

**Cost Optimization Tips:**
1. Use GPT-4o-mini (cheaper) instead of GPT-4
2. Implement caching for common queries
3. Limit conversation history sent to LLM
4. Set max_tokens to prevent long responses

---

## Post-Deployment Checklist

- [ ] All environment variables configured
- [ ] Database migrations run successfully
- [ ] WebSocket connections working
- [ ] Background jobs processing
- [ ] Products have AI searchable tags
- [ ] Smoke test passed
- [ ] Monitoring dashboards configured
- [ ] Alerts configured
- [ ] Team trained on troubleshooting
- [ ] Rollback plan documented and tested
- [ ] Cost tracking enabled
- [ ] Security measures reviewed

---

## Support & Resources

- **Documentation:** `/docs/AI_ASYSTANT_DOCS.md`, `/docs/PRODUCT_SEPARATION_IMPLEMENTATION.md`
- **OpenAI Status:** https://status.openai.com/
- **Langchain Ruby Docs:** https://github.com/patterns-ai-core/langchainrb
- **Spree Guides:** https://guides.spreecommerce.org/

---

*Last Updated: December 16, 2024*
*Version: 1.0*
