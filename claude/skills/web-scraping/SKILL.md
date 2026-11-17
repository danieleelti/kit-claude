---
name: web-scraping
description: This skill activates for web scraping and frontend component extraction. It discovers APIs, detects frameworks, recommends optimal strategy (curl/Playwright/API/hybrid), and implements iteratively. Uses Playwright MCP for browser automation. Also activates for extracting HTML/CSS/JS components from websites.
license: MIT
---

# Web Scraping with Intelligent Strategy Selection

## When This Skill Activates

Activate automatically when user requests:
- "Scrape [website]"
- "Extract data from [site]"
- "Get product information from [URL]"
- "Find all links/pages on [site]"
- "Copy this component from [URL]"
- "Extract the [header/slider/form/etc] from [site]"
- "Get the HTML/CSS/JS from [URL]"
- "Reverse engineer [component] from [site]"
- "I'm getting blocked" or "Getting 403 errors" (loads `strategies/anti-blocking.md`)

## Input Parsing

Determine reconnaissance depth from user request:

| User Says | Mode | Phases Run |
|-----------|------|------------|
| "quick recon", "just check", "what framework" | Quick | Phase 0 only |
| "scrape X", "extract data from X" (default) | Standard | Phases 0-3 + 5, Phase 4 only if protection signals detected |
| "full recon", "deep scan", "production scraping" | Full | All phases (0-5) including protection testing |
| "copy this component", "extract the [widget]" | Component | Phase 0 + targeted DOM extraction via Playwright |

Default is Standard mode. Escalate to Full if protection signals appear during any phase.

## Adaptive Reconnaissance Workflow

This skill uses an adaptive phased workflow with quality gates. Each gate asks **"Do I have enough?"** — continue only when the answer is no.

**See**: `strategies/framework-signatures.md` for framework detection tables referenced throughout.

### Phase 0: QUICK ASSESSMENT (curl, no browser)

Gather maximum intelligence with minimum cost — a single HTTP request.

**Step 0a: Fetch raw HTML and headers**
```bash
curl -s -D- -L "https://target.com/page" -o response.html
```

**Step 0b: Check response headers**
- Match headers against `strategies/framework-signatures.md` → Response Header Signatures table
- Note `Server`, `X-Powered-By`, `X-Shopify-Stage`, `Set-Cookie` (protection markers)
- Check HTTP status code (200 = accessible, 403 = protected, 3xx = redirects)

**Step 0c: Check Known Major Sites table**
- Match domain against `strategies/framework-signatures.md` → Known Major Sites
- If matched: use the specified data strategy, skip generic pattern scanning

**Step 0d: Detect framework from HTML**
- Search raw HTML for signatures in `strategies/framework-signatures.md` → HTML Signatures table
- Look for `__NEXT_DATA__`, `__NUXT__`, `ld+json`, `/wp-content/`, `data-reactroot`

**Step 0e: Search for target data points**
- For each data point the user wants: search raw HTML for that content
- Track which data points are found vs missing
- Check for sitemaps: `curl -s https://[site]/robots.txt | grep -i Sitemap`

**Step 0f: Note protection signals**
- 403/503 status, Cloudflare challenge HTML, CAPTCHA elements, `cf-ray` header
- Record for Phase 4 decision

**See**: `strategies/cheerio-vs-browser-test.md` for the Cheerio viability assessment

> **QUALITY GATE A**: All target data points found in raw HTML + no protection signals?
> → YES: Skip to Phase 3 (Validate Findings). No browser needed.
> → NO: Continue to Phase 1.

### Phase 1: BROWSER RECONNAISSANCE (only if Phase 0 needs it)

Launch Playwright MCP browser for data points missing from raw HTML or when JavaScript rendering is required.

**Step 1a: Open page with Playwright MCP**
- Navigate to target URL
- Wait for full render (networkidle)
- Take screenshot to capture visual state

**Step 1b: Capture rendered DOM and network activity**
- Get full rendered HTML (page.content())
- Monitor network requests for XHR/fetch calls returning JSON
- Identify API endpoints called during page load

**Step 1c: Search rendered DOM for missing data points**
- For each data point NOT found in Phase 0: search rendered DOM
- Use framework-specific search strategy from `strategies/framework-signatures.md`
- Only search patterns relevant to the detected framework

**Step 1d: Inspect discovered endpoints**
- Review captured network requests for API patterns
- Document: method, headers, auth, response structure, pagination

> **QUALITY GATE B**: All target data points now covered (raw HTML + rendered DOM + network)?
> → YES: Skip to Phase 3 (Validate Findings). No deep scan needed.
> → NO: Continue to Phase 2 for missing data points only.

### Phase 2: DEEP SCAN (only for missing data points)

Targeted investigation for data points not yet found. Only search for what's missing.

**Step 2a: Test interactions for missing data**
- Use Playwright to click elements that trigger dynamic content loads
- Scroll to trigger lazy loading / infinite scroll
- Wait for delayed content to appear
- After each action: check for new network requests

**Step 2b: Sniff APIs (framework-aware)**
- Search only patterns relevant to detected framework:
  - Next.js → look for `/_next/data/` requests
  - WordPress → look for `/wp-json/` requests
  - GraphQL → look for `/graphql` or `/gql` requests
  - Generic → look for `/api/` requests + JSON responses
- Skip patterns that don't apply to the detected framework

**Step 2c: Test pagination and filtering**
- Only if pagination data is a missing data point or needed for coverage assessment
- Click next page, observe network requests for pagination patterns
- Document pagination type (URL-based, API offset, cursor, infinite scroll)

> **QUALITY GATE C**: Enough data points covered for a useful report?
> → YES: Go to Phase 3.
> → NO: Document gaps, go to Phase 3 anyway (report will note missing data in self-critique).

### Phase 3: VALIDATE FINDINGS

Every claimed extraction method must be verified. A data point is not "found" until the extraction path is specified and tested.

**See**: `strategies/cheerio-vs-browser-test.md` for validation methodology

**Step 3a: Validate CSS selectors**
- For each selector-based method: confirm the selector matches actual HTML
- Test against raw HTML (curl output) or rendered DOM
- Confirm selector extracts the correct value, not a different element

**Step 3b: Validate JSON paths**
- For each JSON extraction (e.g., `__NEXT_DATA__`, API response): confirm the path resolves
- Parse the JSON, follow the path, verify it returns the expected data type and value

**Step 3c: Validate API endpoints**
- For each discovered API: replay the request with curl
- Confirm: response status 200, expected data structure, correct values
- Test pagination if claimed (at least page 1 and page 2)

**Step 3d: Downgrade or re-investigate failures**
- If a selector doesn't match: try alternative selectors, or downgrade to PARTIAL confidence
- If an API returns 403: note protection requirement, flag for Phase 4
- If a JSON path is wrong: re-examine the JSON structure, correct the path

### Phase 4: PROTECTION TESTING (conditional)

**See**: `strategies/proxy-escalation.md` for complete skip/run decision logic

**Skip Phase 4 when ALL true**:
- No protection signals detected in Phases 0-2
- All data points have validated extraction methods
- User didn't request "full recon"

**Run Phase 4 when ANY true**:
- 403/challenge page observed during any phase
- Known high-protection domain
- High-volume or production intent
- User explicitly requested it

**If running**:

**Step 4a: Test raw HTTP access**
```bash
curl -s -o /dev/null -w "%{http_code}" "https://target.com/page"
```
- 200 → Simple HTTP scraping viable
- 403/503 → Need Playwright with stealth options

**Step 4b: Test with Playwright stealth mode** (if needed)
- Check if pages loaded without challenges in Phase 1
- Look for Cloudflare cookies, CAPTCHA elements, fingerprint markers

**Step 4c: Document protection profile**
- What protections exist, what worked to bypass them, what production scrapers will need

### Phase 5: REPORT + SELF-CRITIQUE

Generate the intelligence report, then critically review it for gaps.

**See**: `reference/report-schema.md` for complete report format

**Step 5a: Generate report**
- Follow `reference/report-schema.md` schema (Sections 1-6)
- Include `Validated?` status for every strategy (YES / PARTIAL / NO)
- Include all discovered endpoints with full specs

**Step 5b: Self-critique**
- Write Section 7 (Self-Critique) per `reference/report-schema.md`:
  - **Gaps**: Data points not found — why, and what would find them
  - **Skipped steps**: Which phases skipped, with quality gate reasoning
  - **Unvalidated claims**: Anything marked PARTIAL or NO
  - **Assumptions**: Things not verified
  - **Staleness risk**: Geo-dependent prices, A/B layouts, session-specific content
  - **Recommendations**: Targeted next steps (not "re-run everything")

**Step 5c: Fix gaps with targeted re-investigation**
- If self-critique reveals fixable gaps: go back to the specific phase/step, not a full re-run
- Update report with results

---

## Component Extraction Mode

When user asks to extract a specific frontend component (header, slider, form, pricing table, etc.):

### Step 1: Load and render the page
- Open URL with Playwright MCP
- Wait for full render (networkidle)
- Take screenshot

### Step 2: Identify the target component
- Ask user to specify which component (or identify from their description)
- Use Playwright to inspect the DOM and isolate the component's root element

### Step 3: Extract HTML
- Get the outerHTML of the component's root element
- Clean up: remove unnecessary data attributes, tracking scripts, analytics

### Step 4: Extract CSS
- Collect all computed styles for the component and its children
- Identify which CSS rules from stylesheets apply to the component
- Extract relevant CSS classes and their definitions
- Look for inline styles and CSS custom properties (variables)

### Step 5: Extract JavaScript
- Identify event listeners attached to the component
- Find related JS files/modules (look at script tags, imports)
- Extract initialization code and interaction logic
- Note external dependencies (libraries, CDN scripts)

### Step 6: Package the result
- Deliver clean, standalone HTML + CSS + JS that reproduces the component
- Note any external dependencies needed (fonts, icons, libraries)
- Flag any server-side logic that can't be extracted (API calls, auth)

---

## IMPLEMENTATION (after reconnaissance)

After reconnaissance report is accepted, implement scraper iteratively.

**Core Pattern**:
1. Implement recommended approach (minimal code)
2. Test with small batch (5-10 items)
3. Validate data quality
4. Scale to full dataset or fallback
5. Handle blocking if encountered
6. Add robustness (error handling, retries, logging)

**See**: `workflows/implementation.md` for complete implementation patterns and code examples

## Quick Reference

| Task | Pattern/Command | Documentation |
|------|----------------|---------------|
| **Reconnaissance** | **Adaptive Phases 0-5** | **`workflows/reconnaissance.md`** |
| Framework detection | Header + HTML signature matching | `strategies/framework-signatures.md` |
| Cheerio vs Browser | Three-way test + early exit | `strategies/cheerio-vs-browser-test.md` |
| Protection testing | Conditional escalation | `strategies/proxy-escalation.md` |
| Report format | Sections 1-7 with self-critique | `reference/report-schema.md` |
| Find sitemaps | robots.txt + common paths | `strategies/sitemap-discovery.md` |
| Discover APIs | Network monitoring via Playwright | `strategies/api-discovery.md` |
| DOM scraping | Playwright page.evaluate() | `strategies/dom-scraping.md` |
| HTTP scraping | curl + parsing | `strategies/cheerio-scraping.md` |
| Hybrid approach | Sitemap + API | `strategies/hybrid-approaches.md` |
| Handle blocking | Stealth mode + headers | `strategies/anti-blocking.md` |
| **Component extraction** | **Playwright DOM isolation** | **See Component Extraction Mode above** |

## Common Patterns

### Pattern 1: Sitemap-Based Scraping
```bash
# Discover sitemaps
curl -s https://example.com/robots.txt | grep -i Sitemap
curl -s https://example.com/sitemap.xml

# Parse and extract URLs, then scrape each
```

### Pattern 2: API-Based Scraping
```bash
# Use discovered API endpoints from reconnaissance
curl -s "https://api.example.com/products/123" -H "Accept: application/json"
```

### Pattern 3: Component Extraction (Playwright)
```javascript
// Via Playwright MCP - isolate and extract a component
const component = await page.$('.pricing-table');
const html = await component.evaluate(el => el.outerHTML);
const styles = await page.evaluate(() => {
  // Extract computed styles and relevant CSS rules
});
```

### Pattern 4: Hybrid (Sitemap + API)
```
1. Get URLs from sitemap
2. Extract IDs from URL patterns
3. Fetch data via discovered API endpoints
```

## Directory Navigation

This skill uses **progressive disclosure** - detailed information is organized in subdirectories and loaded only when needed.

### Workflows (Implementation Patterns)
- `workflows/reconnaissance.md` - **Phase 1 interactive reconnaissance (CRITICAL)**
- `workflows/implementation.md` - Iterative implementation patterns

### Strategies (Deep Dives)
- `strategies/framework-signatures.md` - **Framework detection lookup tables (Phase 0/1)**
- `strategies/cheerio-vs-browser-test.md` - **Cheerio vs Browser decision test with early exit**
- `strategies/proxy-escalation.md` - **Protection testing skip/run conditions (Phase 4)**
- `strategies/traffic-interception.md` - Traffic interception patterns
- `strategies/sitemap-discovery.md` - Complete sitemap guide (4 patterns)
- `strategies/api-discovery.md` - Finding and using APIs
- `strategies/dom-scraping.md` - DOM scraping via Playwright
- `strategies/cheerio-scraping.md` - HTTP-only scraping
- `strategies/hybrid-approaches.md` - Combining strategies
- `strategies/anti-blocking.md` - Anti-detection techniques
- `strategies/session-workflows.md` - Session recording and replay

### Examples (Runnable Code)
- `examples/sitemap-basic.js` - Simple sitemap scraper
- `examples/api-scraper.js` - Pure API approach
- `examples/traffic-interception-basic.js` - Network-based reconnaissance
- `examples/hybrid-sitemap-api.js` - Combined approach
- `examples/iterative-fallback.js` - Try multiple strategies in sequence

### Reference (Quick Lookup)
- `reference/report-schema.md` - **Intelligence report format (Sections 1-7 + self-critique)**
- `reference/regex-patterns.md` - Common URL regex patterns
- `reference/anti-patterns.md` - What NOT to do

**Note**: Each file is self-contained and can be read independently. Claude will navigate to specific files as needed.

## Core Principles

### 1. Assess Before Committing Resources
Start cheap (curl), escalate only when needed:
- Phase 0 (curl) before Phase 1 (Playwright) before Phase 2 (deep scan)
- Quality gates skip phases when data is sufficient
- Never launch a browser if curl gives you everything

### 2. Detect First, Then Search Relevant Patterns
Use framework detection to focus searches:
- Match against `strategies/framework-signatures.md` before scanning
- Skip patterns that don't apply (no `__NEXT_DATA__` on Amazon)
- Known major sites get direct strategy lookup

### 3. Validate, Don't Assume
Every claimed extraction method must be tested:
- "Found text in HTML" is not enough — need a working selector/path
- Phase 3 validates every finding before the report
- Unvalidated claims are marked PARTIAL or NO in the report

### 4. Iterative Implementation
Build incrementally:
- Small test batch first (5-10 items)
- Validate quality
- Scale or fallback
- Add robustness last

---

**Remember**: curl first, Playwright only if needed, APIs over DOM scraping!

For detailed guidance on any topic, navigate to the relevant subdirectory file listed above.
