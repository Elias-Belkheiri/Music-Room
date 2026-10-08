# Music Room — Design System

> Visual identity derived from the reference UI (dark, acid-yellow accent, rounded "neo-brutalist soft" music app aesthetic).
> Goal: a bold, moody, club-night interface where the accent color feels like a highlighter mark on black paper.

---

## 1. Design Language

**Name:** *Acid Noir*

- **Mood:** late-night, warehouse-party energy — dark surfaces, loud yellow, zero chrome.
- **Principles:**
  1. **Black first.** Every surface is a shade of near-black; color is spent only on what matters (CTAs, active states, playback).
  2. **One accent, used loudly.** Acid yellow appears only on interactive/primary elements — never decoration.
  3. **Soft geometry.** Every container is a rounded rectangle or circle; zero sharp corners, zero borders, zero drop-shadows (depth comes from tonal contrast, not shadows).
  4. **Art is the decoration.** Album artwork supplies all the visual richness; the UI frames it and gets out of the way.
  5. **Touch-first.** Minimum tappable target 44×44 pt; primary actions are oversized circular buttons.

---

## 2. Color Tokens

| Token | Hex | Usage |
|---|---|---|
| `color-bg` | `#1C1C1C` | App background, screens |
| `color-surface` | `#262626` | Cards, bottom sheets, list rows |
| `color-surface-raised` | `#2E2E2E` | Overlays on images, progress tracks, pressed states |
| `color-accent` | `#E9FE5C` | Primary CTA, active nav, play/pause, highlights, selection |
| `color-on-accent` | `#141414` | Icons/text placed *on* the accent yellow |
| `color-text-primary` | `#F4F4F4` | Headings, track titles |
| `color-text-secondary` | `#9A9A9A` | Artists, metadata, placeholders, durations |
| `color-overlay` | `rgba(0, 0, 0, 0.55)` | Image legibility scrims (gradient: transparent → black at bottom) |
| `color-danger` | `#FF4D4D` | Reserved: errors, destructive actions only (never decorative) |

**Gradient scrims (mandatory on image cards with text):**
```
linear-gradient(to top, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.35) 45%, rgba(0,0,0,0) 75%)
```

**Contrast rule:** accent yellow is used strictly on dark surfaces; body text on `color-bg`/`color-surface` must meet WCAG AA (≥ 4.5:1) — the palette above complies.

---

## 3. Typography

**Font stack:** `Space Grotesk` (Google Fonts, free) — geometric, slightly quirky, matches the reference aesthetic.
Fallback: `Poppins`, system sans.

| Style | Size / Weight / Case | Usage |
|---|---|---|
| `display` | 32 pt / Bold | Screen titles ("Discover", "Recommended For You Today") |
| `title-lg` | 22 pt / SemiBold | Card titles ("Trap"), sheet headers |
| `title-md` | 17 pt / Medium | Track titles, playlist names |
| `body` | 15 pt / Regular | Album metadata, labels ("studio album · 2018") |
| `caption` | 13 pt / Regular / `color-text-secondary` | Artists, durations, "See all" |
| `label` | 13 pt / SemiBold / UPPERCASE optional | Section labels, badges |

- Titles may use tight letter-spacing (`-0.5pt`); body stays at `0`.
- Numbers (durations, counts) use tabular figures.

---

## 4. Shape & Spacing

**Radii:**
| Token | Value | Usage |
|---|---|---|
| `radius-sm` | 12 px | Small chips, thumbnails in rows |
| `radius-md` | 20 px | List rows, search bar, collection cards |
| `radius-lg` | 28 px | Feature cards, bottom sheets, phone-frame screens |
| `radius-pill` | 999 px | Buttons, bottom nav, avatars, progress track |

**Spacing scale (8 pt base):** 4, 8, 12, 16, 20, 24, 32, 40
- Screen horizontal padding: **20 px**
- Card internal padding: **16–20 px**
- Stack rhythm: title → 12 → content → 16 → next section

**No shadows.** Depth = surface tone steps (`bg` → `surface` → `surface-raised`).

---

## 5. Core Components

### 5.1 Bottom Navigation
- Floating pill bar: `color-surface`, `radius-pill`, height 64 px, horizontal padding 12 px, margin 16 px from screen edges.
- **3 items only** (Library | Home | Settings), each a 44 px circle button.
- **Active state:** `color-accent` fill + `color-on-accent` icon.
- **Inactive state:** transparent + `color-text-secondary` icon.

### 5.2 Primary Circular Button (Play / Pause)
- 64–72 px circle, `color-accent` fill, `color-on-accent` icon, `radius-pill`.
- Play/pause glyphs: filled, centered, no ring, no border.

### 5.3 Secondary Circular Button (Skip / Back)
- Same geometry as primary but `color-surface-raised` fill + `color-text-primary` icon.

### 5.4 Search Pill
- Full-width, height 52 px, `radius-pill`, `color-surface` fill.
- Magnifier icon + placeholder text `color-text-secondary` ("search").

### 5.5 Feature Card (genre / event)
- Aspect ~4:5, `radius-lg`, full-bleed artwork, title bottom-left over the scrim gradient (`display` size, white), circular play button bottom-right (accent or white).

### 5.6 Track Row
- Height 64 px: 48 px square thumbnail (`radius-sm`) | title (`title-md`) + artist (`caption`) | duration right-aligned (`caption`).

### 5.7 Collection Card (horizontal scroll)
- Square 1:1, `radius-md`, artwork + title + artist label below the image (not overlaid).

### 5.8 Player Sheet
- `radius-lg` top corners, full-bleed hero image top, then:
  - Track title (`title-lg`) + album (`body`) on a `color-surface-raised` panel
  - **Waveform progress bar**: ~40 px tall rounded bars; played portion `color-accent`, unplayed `#5A5A5A`; scrubbable
  - Controls row: secondary (back) — **primary (pause, accent, elevated)** — secondary (skip); outer 32 px, center 64 px

### 5.9 Chips / Tags
- Pill, `color-surface-raised` fill, `caption` text; active chip = `color-accent` fill.

### 5.10 Section Header
- Title (`display` or `title-lg`) left + "See all" (`caption`, `color-text-secondary`) right, aligned on the same baseline.

---

## 6. Screens (Mapped to Music Room Features)

| Screen | Notes |
|---|---|
| **Discover / Home** | Greeting/search, genre feature cards (horizontal), "Your playlist" rail → feeds *Music Playlist Editor* |
| **Now Playing** | Hero art, waveform seek, controls; hosts *Music Track Vote* "suggest next" entry & *Music Control Delegation* hand-off |
| **Recommended / Explore** | Search pill, "Recommended For You Today", "New Collection" grid → public playlists & events (visibility: public/private) |
| **Queue / Vote view** (implied) | Track rows with vote count + upvote; live resort animated on vote; ties into the accent color for the user's own vote |
| **Auth** | Dark screens, email/password or Facebook/Google buttons; Google = white button / dark glyph, Facebook = `#1877F2`; email CTA = accent |

---

## 7. Motion

- **Vote resort:** 250 ms ease-out layout animation (FLIP-style) when queue reorders.
- **Sheet open:** 300 ms spring, slides up with `radius-lg` corners.
- **Active nav:** 150 ms color cross-fade (no scaling).
- **Playback pulse:** optional subtle 2 s scale pulse (1.0 → 1.04) on the pause button while playing.
- Easing: `cubic-bezier(0.22, 1, 0.36, 1)`.

---

## 8. Assets & Iconography

- Icons: filled, rounded, single-weight (2.5 px stroke equivalent) — Lucide / Phosphor "fill" style.
- Album art always fills its container (`scaleType: centerCrop` / `contentMode: .scaleAspectFill`).
- App icon: black rounded square, acid-yellow waveform or note glyph (mirrors accent-on-black language).

---

## 9. Accessibility & Theming Checklist

- [ ] Text on images only over scrim gradient
- [ ] All icon-only buttons have accessibility labels
- [ ] Accent never used for non-interactive elements (screen-reader & visual hierarchy sanity)
- [ ] Dynamic type: support up to 130% without truncation of track titles (wrap to 2 lines max)
- [ ] Reduced-motion flag disables pulse/sheet spring
- [ ] Dark theme only — no light variant in v1

---

## 10. Quick Reference (for dev handoff)

```css
:root {
  --bg: #1C1C1C;
  --surface: #262626;
  --surface-raised: #2E2E2E;
  --accent: #E9FE5C;
  --on-accent: #141414;
  --text: #F4F4F4;
  --text-secondary: #9A9A9A;
  --radius-sm: 12px;
  --radius-md: 20px;
  --radius-lg: 28px;
  --radius-pill: 999px;
}
```
