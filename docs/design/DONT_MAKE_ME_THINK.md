# Don't Make Me Think - Usability Principles

**Author:** Steve Krug
**Year:** 2000 (updated 2014)
**Core Philosophy:** Good web design means people should understand what the page is about, what they can do there, and where to go next—without thinking too hard.

---

## The First Law of Usability

**"Don't make me think"**

- Users don't read pages, they scan them
- Users don't make optimal choices, they satisfice
- Users don't figure out how things work, they muddle through

### What Makes People Think?

1. **Unclear navigation** - "Where am I?"
2. **Hidden options** - "What can I do here?"
3. **Unfamiliar patterns** - "Is this clickable?"
4. **Ambiguous labels** - "What does this mean?"
5. **Cognitive overload** - Too much information at once

---

## The 5 Key Principles

### 1. Create a Clear Visual Hierarchy

**What:** Make important things prominent and less important things less so.

**How:**
- Size matters: Bigger = more important
- Weight matters: Bold/darker = more important
- Position matters: Top/left = more important
- Color matters: Brighter = more important
- Proximity matters: Closer = related
- Whitespace matters: More separation = less related

**Example:** A "Start Timer" button should be:
- Prominent (large, bold color)
- Positioned prominently (top or center)
- Clearly labeled (not ambiguous icons)
- Well-spaced from less important elements

### 2. Use Conventions

**What:** Use familiar patterns people already know.

**Why:** Users spend 99% of their time on OTHER sites. Don't reinvent the wheel.

**Examples:**
- Search in the top-right or top-center
- Logo in the top-left, clickable to home
- Cart in the top-right with count
- Links look clickable (underline or hover state)
- Buttons look clickable (border, background, or prominent)
- "Hamburger" menu icon for collapsed navigation
- Tabs for related content views
- Progress indicators show current step

**Don't:**
- Hide navigation in unexpected places
- Make non-clickable things look clickable
- Make clickable things look non-clickable
- Use novel patterns without good reason

### 3. Break Pages into Clearly Defined Areas

**What:** Use visual separation to create distinct regions.

**How:**
- Whitespace/gutters between sections
- Subtle borders or dividers
- Background color differences
- Card/grouping patterns
- Section headers

**Example in a timer app:**
```
┌─────────────────────────────────┐
│ [Header] Focally        [Settings] │ ← Top bar
├─────────────────────────────────┤
│                                 │
│     [Main Timer Display]         │ ← Primary content
│      25:00                       │   (most whitespace)
│                                 │
├─────────────────────────────────┤
│  [Start]  [Pause]  [Stop]       │ ← Controls
├─────────────────────────────────┤
│  [Quick Tasks]  [History]        │ ← Secondary
└─────────────────────────────────┘
```

### 4. Make It Obvious What's Clickable

**What:** Interactive elements should scream "click me."

**How:**
- Buttons: Border, background, hover state, cursor pointer
- Links: Underline or color change, hover state
- Icons: Tooltip or label if ambiguous
- Touch targets: Minimum 44x44 points (mobile), 32x32 (desktop)

**Don't:**
- Make plain text clickable without visual cue
- Make non-interactive things look interactive
- Hide functionality behind obscure gestures
- Require users to discover by trial-and-error

### 5. Minimize Noise

**What:** Remove visual clutter that distracts from primary purpose.

**How:**
- Remove redundant words
- Use fewer, better words
- Remove decorative elements that don't add value
- Use whitespace to create focus
- Hide advanced features until needed
- Progressive disclosure: Show simple, reveal complex

**Krug's Guide to Removing Noise:**

| What to Remove | Why | Example |
|----------------|-----|---------|
| Happy talk | No one reads it | "Welcome to our amazing app!" |
| Instructions | If you need them, design failed | "Click here to continue" |
| Dead words | Clutter | "Click" vs "Submit Form" |
| Repeated labels | Obvious context | "Email Address:" vs "Email:" |
| Decorative icons | Distraction | Purely ornamental graphics |

---

## Navigation

### The Three Critical Questions

Users must be able to answer these at ALL times:

1. **"Where am I?"**
   - Page title
   - Breadcrumbs or current section highlight
   - Visual hierarchy
   - Context indicators

2. **"What's here?"**
   - Clear section headers
   - Scannable content
   - Logical grouping
   - Visual hierarchy

3. **"Where can I go from here?"**
   - Clear navigation labels
   - Navigation highlighting current page
   - Related links
   - Next/prev indicators

### Tabbed Navigation vs. Drop-down

**Use Tabs when:**
- 3-7 related sections
- Users switch frequently
- Sections are equally important
- Quick access is priority

**Use Drop-downs when:**
- Many sections
- Users switch infrequently
- Some sections are primary, others secondary
- Space is limited

---

## Accessibility

### It's Not Just About Blind Users

Good accessibility helps EVERYONE:
- Colorblind users (don't rely on color alone)
- Motor-impaired users (keyboard shortcuts, large targets)
- Cognitive users (clear language, consistency)
- Temporary injuries (broken arm, sprained wrist)
- Situational constraints (bright light, noisy environment)

### Key Principles

1. **Provide alternative text** for images
2. **Use semantic HTML/SwiftUI** (proper controls, not decorative text)
3. **Support keyboard navigation** (tab order, shortcuts)
4. **Don't rely on color alone** (icons, shapes, patterns)
5. **Provide clear feedback** (loading states, errors, success)
6. **Use accessible color contrast** (WCAG AA minimum)

---

## The "You Are Here" Indicator

Users get disoriented easily. Show them where they are:

### In Web:
- Breadcrumb navigation: Home > Settings > Profile
- Active state in navigation menu
- Page title in header
- URL structure

### In Apps:
- Tab bar highlighting current tab
- Section title in header
- Back button hierarchy
- Screen title prominent

---

## Error Messages

### Good Error Messages

1. **Visible** - Not hidden in console or subtle toast
2. **Specific** - What went wrong exactly?
3. **Constructive** - How to fix it?
4. **Polite** - Don't blame the user

**Bad:** "An error occurred"
**Better:** "Could not connect to Slack. Check your token and try again."
**Best:** "Slack token is invalid. [View guide] or [try again]."

---

## Mobile Considerations

### Smaller Screen = Less Thinking Budget

- Minimize cognitive load
- Progressive disclosure (reveal on demand)
- Touch targets: 44x44 points minimum
- Single-focus screens
- Avoid scrolling if possible

---

## Testing

### Krug's Testing Approach

1. **Test early and often**
2. **You don't need many users** - 3-5 is enough to find major issues
3. **You don't need a formal lab** - Just sit next to someone
4. **You don't need professional testers** - Real users are best
5. **You can test anything** - Wireframes, prototypes, live code

### What to Watch For

1. **Hesitation** - User pauses before clicking
2. **Backtracking** - User goes somewhere then returns
3. **Confusion** - "What's this supposed to do?"
4. **Errors** - Especially preventable ones
5. **Workarounds** - User figures out a kludge

---

## The "Why" Check

Before adding anything to your UI, ask:

1. **Does it help the user achieve their goal?**
2. **Is it obvious what it does?**
3. **Is it in the right place?**
4. **Could it be simpler?**
5. **Could it be removed entirely?**

---

## Anti-Patterns (What to Avoid)

### 1. Mystery Meat Navigation
Icons without labels that users have to hover/click to understand.

**Fix:** Add tooltips or labels for ambiguous icons.

### 2. Surprise Features
Functionality hidden behind non-obvious interactions (right-click, long-press, swipe).

**Fix:** Make primary actions discoverable. If it's a feature, show it.

### 3. Overloaded Home Pages
Too many options, no clear path forward.

**Fix:** Focus on 1-3 primary actions. Move secondary options deeper.

### 4. Inconsistent Patterns
Different UI patterns for similar functions.

**Fix:** Pick ONE pattern and use it consistently throughout.

### 5. Buried Sign-up/Login
Hard to find or start using the app.

**Fix:** Clear, prominent call-to-action for primary action.

---

## Quick Audit Checklist

Use this to audit any UI:

- [ ] Can users answer "Where am I? What's here? Where can I go?" at all times?
- [ ] Is the primary action obvious (size, color, position)?
- [ ] Are interactive elements clearly clickable (hover states, borders)?
- [ ] Is visual hierarchy clear (most important is most prominent)?
- [ ] Are familiar conventions used (icons, navigation patterns)?
- [ ] Is navigation minimal (3-7 primary items)?
- [ ] Is whitespace used effectively (not cluttered)?
- [ ] Are sections clearly defined (grouping, dividers)?
- [ ] Are error messages specific and actionable?
- [ ] Is content scannable (headings, bullets, short paragraphs)?

---

## Resources

**Book:** "Don't Make Me Think" by Steve Krug (Revised Edition)
**Website:** www.sensible.com

**Related Books:**
- "The Design of Everyday Things" by Don Norman
- "About Face" by Alan Cooper
- "Rocket Surgery Made Easy" by Steve Krug (usability testing handbook)