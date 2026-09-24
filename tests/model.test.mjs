// Unit tests for KeyboardLayoutModel.js. Run with: node tests/model.test.mjs
import assert from "node:assert/strict"
import model from "../KeyboardLayoutModel.js"

let passed = 0
const failures = []

function test(name, fn) {
  try {
    fn()
    passed++
    console.log("ok:", name)
  } catch (error) {
    failures.push(name)
    console.error("FAIL:", name, "-", error.message)
  }
}

const CATALOG_FIXTURE = `layouts:
- layout: 'us'
  variant: ''
  brief: 'en'
  description: English (US)
- layout: 'ru'
  variant: ''
  brief: 'ru'
  description: Russian
- layout: 'gr'
  variant: ''
  brief: 'gr'
  description: Greek
- layout: 'us'
  variant: 'intl'
  brief: 'en'
  description: English (US, intl.)
option_groups:
- name: 'ctrl'
  description: Ctrl keys
  options:
  - name: 'ctrl:nocaps'
    brief: ''
    description: 'Make Caps Lock an additional Ctrl'
- name: 'grp'
  description: Switching to another layout
  options:
  - name: 'grp:alt_shift_toggle'
    brief: ''
    description: 'Alt+Shift'
  - name: 'grp:ctrl_space_toggle'
    brief: ''
    description: 'Ctrl+Space'
  - name: 'grp:switch'
    brief: ''
    description: 'Right Alt (while pressed)'
`

test("parseCatalog collects layouts and toggle shortcuts", () => {
  const catalog = model.parseCatalog(CATALOG_FIXTURE)
  assert.equal(catalog.layouts.length, 4)
  assert.equal(catalog.layouts[0].description, "English (US)")
  assert.equal(catalog.layouts[0].brief, "en")
  const values = catalog.shortcuts.map((s) => s.value)
  assert.deepEqual(values, ["grp:alt_shift_toggle", "grp:ctrl_space_toggle"])
  assert.equal(catalog.shortcuts[0].label, "Alt+Shift")
})

test("parseCatalog on empty input returns empty catalog", () => {
  const catalog = model.parseCatalog("")
  assert.deepEqual(catalog.layouts, [])
  assert.deepEqual(catalog.shortcuts, [])
})

const catalog = model.parseCatalog(CATALOG_FIXTURE)

test("labelFor derives 2-letter codes from briefs", () => {
  assert.equal(model.labelFor(catalog, "us", "", ""), "EN")
  assert.equal(model.labelFor(catalog, "ru", "", ""), "RU")
  assert.equal(model.labelFor(catalog, "gr", "", ""), "GR")
})

test("labelFor prefers a valid alias", () => {
  assert.equal(model.labelFor(catalog, "us", "", "Work"), "Work")
})

test("labelFor ignores invalid aliases", () => {
  assert.equal(model.labelFor(catalog, "us", "", "toolong1"), "EN")
})

test("labelFor falls back for unknown layouts", () => {
  const label = model.labelFor(catalog, "xyz", "", "")
  assert.equal(label.length, 2)
})

test("descriptionFor resolves catalog entries", () => {
  assert.equal(model.descriptionFor(catalog, "ru", ""), "Russian")
  assert.equal(model.descriptionFor(catalog, "us", "intl"), "English (US, intl.)")
})

test("aliasError enforces length and control characters", () => {
  assert.equal(model.aliasError("Work"), "")
  assert.equal(model.aliasError("toolong1"), "Use 6 characters or fewer.")
  assert.equal(model.aliasError("a\u0007b"), "Aliases cannot contain control characters.")
  assert.equal(model.aliasLength("Работа"), 6)
})

test("normalizeAlias trims", () => {
  assert.equal(model.normalizeAlias("  Ok  "), "Ok")
})

test("normalizeHotkey canonicalizes combos", () => {
  assert.equal(model.normalizeHotkey("ctrl+space"), "CTRL + SPACE")
  assert.equal(model.normalizeHotkey("super + shift + s"), "SUPER + SHIFT + S")
})

test("hotkeyError requires a modifier and a key", () => {
  assert.equal(model.hotkeyError("ctrl + space"), "")
  assert.equal(model.hotkeyError("SUPER + SHIFT + S"), "")
  assert.match(model.hotkeyError("JUSTONEKEY"), /modifier/)
  assert.match(model.hotkeyError("CTRL + SHIFT"), /modifier/)
  assert.match(model.hotkeyError(""), /Press/)
})

test("normalizeLayouts keeps valid entries and latin flags", () => {
  const out = model.normalizeLayouts([
    { layout: "us", variant: "", latin: true, alias: "Me" },
    { layout: "bad name", variant: "" },
    { layout: "ru", variant: "bad variant!" },
    null,
  ])
  assert.equal(out.length, 1)
  assert.equal(out[0].layout, "us")
  assert.equal(out[0].latin, true)
  assert.equal(out[0].alias, "Me")
})

test("duplicate detects repeats", () => {
  const layouts = [{ layout: "us", variant: "" }, { layout: "ru", variant: "" }]
  assert.equal(model.duplicate(layouts, "ru", ""), true)
  assert.equal(model.duplicate(layouts, "ru", "phonetic"), false)
})

test("canDelete guards the last layout and latin-first", () => {
  assert.equal(model.canDelete([{ layout: "us", variant: "", latin: true }], 0).ok, false)
  const mixed = [
    { layout: "us", variant: "", latin: true },
    { layout: "ru", variant: "", latin: false },
  ]
  assert.equal(model.canDelete(mixed, 1).ok, true)
  assert.equal(model.canDelete(mixed, 0).ok, false)
  assert.match(model.canDelete(mixed, 0).reason, /Latin/)
})

test("canMove swaps neighbors and keeps latin first", () => {
  const layouts = [
    { layout: "us", variant: "", latin: true },
    { layout: "ru", variant: "", latin: false },
    { layout: "gr", variant: "", latin: false },
  ]
  assert.equal(model.canMove(layouts, 1, -1).ok, false) // ru would lead
  assert.equal(model.canMove(layouts, 0, -1).ok, false) // already first
  assert.equal(model.canMove(layouts, 2, 1).ok, false) // already last
  assert.equal(model.canMove(layouts, 0, 1).ok, false) // ru would lead
  assert.equal(model.canMove(layouts, 2, -1).ok, true)
  const twoLatins = [
    { layout: "fr", variant: "", latin: true },
    { layout: "us", variant: "", latin: true },
    { layout: "ru", variant: "", latin: false },
  ]
  assert.equal(model.canMove(twoLatins, 0, 1).ok, true)
  assert.equal(model.canMove(twoLatins, 1, 1).ok, true)
})

test("baseLayoutOptions hides layouts with no free variants", () => {
  const options = model.baseLayoutOptions(catalog, [{ layout: "us", variant: "" }])
  const values = options.map((o) => o.value)
  assert.equal(values.includes("us"), true) // us-intl is still free
  assert.equal(values.includes("ru"), true)
  const exhausted = model.baseLayoutOptions(catalog, [
    { layout: "us", variant: "" },
    { layout: "us", variant: "intl" },
  ])
  assert.equal(exhausted.map((o) => o.value).includes("us"), false)
})

test("variantOptions lists unused variants", () => {
  const options = model.variantOptions(catalog, "us", [{ layout: "us", variant: "" }])
  const values = options.map((o) => o.value)
  assert.deepEqual(values, ["intl"])
})

test("popupPlacement prefers below and flips above", () => {
  const below = model.popupPlacement(100, 10, 80, 20, 800, 600, 100, 12, 4)
  assert.equal(below.above, false)
  assert.equal(below.y, 34)
  const above = model.popupPlacement(100, 560, 80, 20, 800, 600, 200, 12, 4)
  assert.equal(above.above, true)
})

test("isTypedKeyboard filters virtual devices only", () => {
  assert.equal(model.isTypedKeyboard("royuan-2.4g-wireless-keyboard"), true)
  assert.equal(model.isTypedKeyboard("royuan-2.4g-wireless-keyboard-1"), true)
  assert.equal(model.isTypedKeyboard("royuan-2.4g-wireless-keyboard-consumer-control"), false)
  assert.equal(model.isTypedKeyboard("power-button"), false)
  assert.equal(model.isTypedKeyboard("hl-virtual-keyboard-fcitx5"), false)
  assert.equal(model.isTypedKeyboard("edifier-es60-(avrcp)"), false)
})

test("eventKeyboardName parses event payloads", () => {
  assert.equal(model.eventKeyboardName({ data: "my-keyboard,us" }), "my-keyboard")
  assert.equal(model.eventKeyboardName({ data: "hl-virtual-keyboard-1,us" }), "")
})

test("selectKeyboard prefers the event keyboard, else furthest along", () => {
  const typed = [
    { name: "a", active_layout_index: 0 },
    { name: "b", active_layout_index: 2 },
    { name: "c", active_layout_index: 1 },
  ]
  assert.equal(model.selectKeyboard(typed, "c").name, "c")
  assert.equal(model.selectKeyboard(typed, "missing").name, "b")
})

console.log(`\n${passed} passed, ${failures.length} failed`)
if (failures.length > 0) process.exit(1)
