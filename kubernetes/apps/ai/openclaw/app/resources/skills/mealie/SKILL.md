---
name: mealie
description: Manage recipes in Mealie v3.14.0 — create, search, tag, categorize, import from URLs, and bulk operations. Use when user asks about recipes, cooking, meal planning, or Mealie. Triggers on recipe, cooking, mealie, meal plan, ingredients, food.
---

# Mealie Recipe Management

Mealie v3.14.0 recipe manager at `http://mealie.default.svc.cluster.local:9000` (external: `mealie.goyangi.io`).

## Auth

```bash
TOKEN=$(op read "op://kubernetes/mealie/MEALIE_API_KEY")
MEALIE=http://mealie.default.svc.cluster.local:9000
AUTH="Authorization: Bearer $TOKEN"
```

All examples below assume `$TOKEN`, `$MEALIE`, and `$AUTH` are set.

## Critical Gotchas

1. **PATCH silently drops `recipeIngredient` and `recipeInstructions`** — always use GET + PUT pattern instead
2. **Ingredient `quantity` must be 0** with full text in `note` field — otherwise display doubles up (e.g. "8 8 cups water")
3. **POST `/api/recipes`** only creates a scaffold from `{"name": "..."}` and returns the slug — you must GET then PUT to populate
4. **Tags and categories must exist first** — create via `/api/organizers/tags` and `/api/organizers/categories` before referencing
5. **Ingredients need `referenceId` (UUID)**, instructions need `id` (UUID) — generate with `uuidgen` or `python3 -c "import uuid; print(uuid.uuid4())"`
6. **Instructions require all fields**: `id`, `title`, `summary`, `text`, `ingredientReferences`

## Recipes

### Create a Recipe (POST + GET + PUT pattern)

This is the only reliable way to create a fully populated recipe.

```bash
# Step 1: Create scaffold (returns slug as plain string)
SLUG=$(curl -s -X POST "$MEALIE/api/recipes" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name": "My Recipe"}')
# Remove quotes if returned as JSON string
SLUG=$(echo "$SLUG" | tr -d '"')

# Step 2: GET the full recipe object
curl -s "$MEALIE/api/recipes/$SLUG" -H "$AUTH" > /tmp/recipe.json

# Step 3: Modify with jq or python, then PUT back
# (see python helper below for complex recipes)
curl -s -X PUT "$MEALIE/api/recipes/$SLUG" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d @/tmp/recipe.json
```

### Search Recipes

```bash
# Paginated list (default page=1, perPage=50)
curl -s "$MEALIE/api/recipes?page=1&perPage=20" -H "$AUTH"

# Search by name (queryFilter uses ORM filter syntax)
curl -s "$MEALIE/api/recipes?search=congee&page=1&perPage=10" -H "$AUTH"

# Filter by category slug
curl -s "$MEALIE/api/recipes?categories=ramen-soups&page=1&perPage=50" -H "$AUTH"

# Filter by tag slug
curl -s "$MEALIE/api/recipes?tags=japanese&page=1&perPage=50" -H "$AUTH"

# Get full recipe by slug
curl -s "$MEALIE/api/recipes/$SLUG" -H "$AUTH"
```

Response shape: `{ page, per_page, total, total_pages, items: [...] }`

### Update a Recipe

Always GET first, modify, then PUT the full object back.

```bash
curl -s "$MEALIE/api/recipes/$SLUG" -H "$AUTH" > /tmp/recipe.json
# Edit /tmp/recipe.json ...
curl -s -X PUT "$MEALIE/api/recipes/$SLUG" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d @/tmp/recipe.json
```

### Delete a Recipe

```bash
curl -s -X DELETE "$MEALIE/api/recipes/$SLUG" -H "$AUTH"
```

### Duplicate a Recipe

```bash
curl -s -X POST "$MEALIE/api/recipes/$SLUG/duplicate" -H "$AUTH"
```

## Tags & Categories

Tags and categories must be created before they can be assigned to recipes.

### List

```bash
curl -s "$MEALIE/api/organizers/tags?page=1&perPage=100" -H "$AUTH"
curl -s "$MEALIE/api/organizers/categories?page=1&perPage=100" -H "$AUTH"
```

### Create

```bash
# Create tag — returns object with id, name, slug
curl -s -X POST "$MEALIE/api/organizers/tags" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name": "japanese"}'

# Create category
curl -s -X POST "$MEALIE/api/organizers/categories" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name": "Ramen - Soups"}'
```

### Assign to Recipe

Include the full tag/category objects (with `id`, `name`, `slug`) in the PUT body:

```json
{
  "tags": [{"id": "uuid-here", "name": "japanese", "slug": "japanese"}],
  "recipeCategory": [{"id": "uuid-here", "name": "Ramen - Soups", "slug": "ramen-soups"}]
}
```

### Tools (Equipment)

```bash
curl -s "$MEALIE/api/organizers/tools?page=1&perPage=100" -H "$AUTH"
curl -s -X POST "$MEALIE/api/organizers/tools" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name": "Dutch Oven"}'
```

## Import from URL

### Mealie's Built-in Scraper

```bash
# Test scrape first (doesn't create)
curl -s -X POST "$MEALIE/api/recipes/test-scrape-url" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/recipe", "includeTags": true}'

# Import (creates recipe, returns slug)
curl -s -X POST "$MEALIE/api/recipes/create/url" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/recipe", "includeTags": true}'
```

### When Scraper Fails — Manual Fallback

If Mealie's scraper can't parse the site, use `agent-browser` or `summarize` to extract content, then create manually:

```bash
# 1. Scrape with agent-browser
agent-browser open "https://example.com/recipe"
agent-browser snapshot -i  # get page content

# 2. Or use summarize
summarize "https://example.com/recipe" --length long --plain

# 3. Parse the content and create via POST + GET + PUT pattern
```

### Import from HTML/JSON

```bash
curl -s -X POST "$MEALIE/api/recipes/create/html-or-json" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"data": "<html>...</html>"}'
```

## Bulk Operations

### Bulk Tag

```bash
curl -s -X POST "$MEALIE/api/recipes/bulk-actions/tag" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"recipes": ["slug-1", "slug-2"], "tags": [{"id": "tag-uuid", "name": "tagname", "slug": "tagname"}]}'
```

### Bulk Categorize

```bash
curl -s -X POST "$MEALIE/api/recipes/bulk-actions/categorize" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"recipes": ["slug-1", "slug-2"], "categories": [{"id": "cat-uuid", "name": "Category", "slug": "category"}]}'
```

### Bulk Delete

```bash
curl -s -X POST "$MEALIE/api/recipes/bulk-actions/delete" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"recipes": ["slug-1", "slug-2"]}'
```

### Bulk Export

```bash
# Start export
curl -s -X POST "$MEALIE/api/recipes/bulk-actions/export" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"recipes": ["slug-1", "slug-2"]}'

# List exports
curl -s "$MEALIE/api/recipes/bulk-actions/export" -H "$AUTH"

# Download
curl -s "$MEALIE/api/recipes/bulk-actions/export/{export_id}/download" -H "$AUTH" -o export.zip
```

### Bulk URL Import

```bash
curl -s -X POST "$MEALIE/api/recipes/create/url/bulk" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"imports": [{"url": "https://example.com/recipe1"}, {"url": "https://example.com/recipe2"}]}'
```

## Ingredient & Instruction Schema

### Ingredient Object

```json
{
  "referenceId": "generated-uuid",
  "quantity": 0,
  "unit": null,
  "food": null,
  "note": "2 cups all-purpose flour",
  "display": "2 cups all-purpose flour",
  "title": null,
  "originalText": null
}
```

Set `quantity: 0` and put the full human-readable text in `note`. This prevents Mealie from doubling up the display (e.g. showing "2 2 cups flour").

### Instruction Object

```json
{
  "id": "generated-uuid",
  "title": "",
  "summary": "",
  "text": "Mix flour and water until smooth.",
  "ingredientReferences": []
}
```

All fields are required. `id` must be a UUID.

## Python Helper

For complex recipe creation, use the upload script pattern from `scripts/mealie-upload-v2.py`:

```python
import uuid, json, urllib.request, subprocess

MEALIE = "http://mealie.default.svc.cluster.local:9000"
TOKEN = subprocess.run(
    ["op", "read", "op://kubernetes/mealie/MEALIE_API_KEY"],
    capture_output=True, text=True
).stdout.strip()

def api(method, path, data=None):
    headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(f"{MEALIE}{path}", data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())

def make_ingredient(text):
    return {"quantity": 0, "unit": None, "food": None, "note": text,
            "display": text, "title": None, "originalText": None,
            "referenceId": str(uuid.uuid4())}

def make_step(text):
    return {"id": str(uuid.uuid4()), "title": "", "summary": "",
            "text": text, "ingredientReferences": []}

def create_recipe(name, ingredients, steps, tags=None, categories=None, description=""):
    """Create a recipe using POST + GET + PUT pattern."""
    slug = api("POST", "/api/recipes", {"name": name})
    if isinstance(slug, dict):
        slug = slug.get("slug", "")
    slug = str(slug).strip('"')

    full = api("GET", f"/api/recipes/{slug}")
    full["recipeIngredient"] = [make_ingredient(i) for i in ingredients]
    full["recipeInstructions"] = [make_step(s) for s in steps]
    full["tags"] = tags or []
    full["recipeCategory"] = categories or []
    full["description"] = description
    return api("PUT", f"/api/recipes/{slug}", full)
```

## Other Useful Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/recipes/suggestions` | GET | Get recipe suggestions |
| `/api/recipes/{slug}/image` | PUT | Upload recipe image |
| `/api/recipes/{slug}/image` | POST | Scrape image from URL body `{"url": "..."}` |
| `/api/recipes/{slug}/assets` | POST | Upload recipe asset (multipart) |
| `/api/recipes/{slug}/last-made` | PATCH | Update last-made date |
| `/api/recipes/{slug}/comments` | GET | Get recipe comments |
| `/api/comments` | POST | Add comment `{"recipeId": "uuid", "text": "..."}` |
| `/api/households/mealplans` | GET/POST | Meal planning |
| `/api/households/mealplans/today` | GET | Today's meal plan |
| `/api/households/shopping/lists/{id}/recipe` | POST | Add recipe ingredients to shopping list |
| `/api/foods` | GET/POST | Manage food items |
| `/api/shared/recipes` | POST | Create shared recipe link |

## Notes

- 99 recipes currently in the instance
- External URL: `https://mealie.goyangi.io`
- Existing upload scripts: `scripts/mealie-upload.py` (v1, PATCH-based, broken for ingredients) and `scripts/mealie-upload-v2.py` (v2, proper GET+PUT)
- For recipes from Obsidian vault, see the upload scripts for markdown parsing patterns
