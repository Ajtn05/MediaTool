# MediaTool Style Guide

Modern is the default macOS utility style. Classic keeps the original cream and black design,
square borders, uppercase headings, and an independent accent choice.

The source of truth is `Sources/MediaTool/Views/Appearance/Theme.swift` for tokens,
`Sources/MediaTool/Views/Components/Controls.swift` for shared components, and
`Sources/MediaTool/Views/ModernWorkspace.swift` for the default layout.

## Modern appearance

Use neutral surfaces and macOS system text colors. Reserve the selected accent for navigation
icons, primary actions, selected segments, switches, sliders, and progress. Changing the accent
must leave the window's surfaces and text neutral.

Modern follows the user's System, Light, or Dark appearance preference. Dark mode uses warm
charcoal settings panels and a darker file canvas, inspired by built-in macOS utility apps.
The sidebar uses native translucent material.

| Token | Purpose |
|---|---|
| `background` | Settings pane, toolbar, and footer |
| `workspace` | File workspace and empty-state canvas |
| `surface` | Rounded groups of related settings |
| `surfaceVariant` | Recessed preview and command wells |
| `controlBackground` | Text fields, secondary buttons, and segmented-control tracks |
| `checkboxBackground` | Flat unchecked Classic checkbox |
| `selection` | Quiet gray sidebar selection |
| `onSurface` | Native primary text |
| `onSurfaceVariant` | Native secondary text and captions |
| `outline` | Control and drop-target outlines |
| `outlineVariant` | Subtle pane dividers and separators |
| `primary` | User-selected native macOS accent |
| `onPrimary` | White on accent fills; black on yellow |
| `primaryContainer` | Translucent accent fill for notices |
| `onPrimaryContainer` | Notice text |
| `secondaryContainer` | Neutral secondary-action fill |
| `onSecondaryContainer` | Secondary-action text |
| `error` | Failure and destructive-action color |

Use `Palette` tokens in views. Keep literal colors in `Theme.swift`. Do not tint backgrounds
with the accent or dim ordinary text with opacity. Disabled primary actions use a neutral fill
and secondary text rather than fading an entire button.

## Layout

At widths of 900 points or more, Modern shows an optional 180-point sidebar, the file workspace,
and a resizable settings inspector. Navigation groups operations under Video, Audio, and Images.
The selected sidebar row has a rounded gray fill and keeps its blue (or chosen accent) icon.

The toolbar shows the active operation and preset controls. Its operation menu remains available
when the sidebar is hidden or the window is narrow. At widths below 700 points, files and settings
share one scroll view. The output controls stay accessible at the bottom.

Empty workspaces center a large, lightly dashed drop target. Once files are added, the file pane
shows a compact drop target and the staging list. Preserve file import, drag and drop, metadata,
removal, and queue behavior when adjusting this layout.

Modern settings sections place their heading above a rounded group. They have no drop shadows
or heavy card borders. Labels align to the leading edge of a consistent caption column, with
native pop-ups, sliders, and compact switches beside them. Pop-up frames use
`alignment: .leading` so different menu widths remain aligned.

## Geometry and type

| Token | Modern | Classic |
|---|---|---|
| `hairline` | 1 pt | 1.5 pt |
| `gutter` | 16 pt | 14 pt |
| `cardPadding` | 14 pt | 14 pt |
| `cardRadius` | 12 pt | 0 pt |
| `controlRadius` | 7 pt | 0 pt |
| `labelColumn` | 104 pt | 124 pt |

Modern buttons use rounded rectangles. Segments sit inside an inset rounded
track; the selected segment has an accent fill and retains its original icon and label.
Separate settings groups by 24 points in the inspector and rows by 14 points within a group.

Use `TypeScale` roles rather than ad hoc fonts. Modern uses the macOS system font and sentence
case. Classic uses compact uppercase Arial Black headings: 12-point mode tabs, 10.5-point section
headings and primary buttons, and 9.5-point labels and secondary buttons. Body text is 11 points.

Classic's main box and control borders are 1.5 points. Its quieter internal dividers are 1 point.
Focus rings and preview drag handles can remain 2 points because they indicate interaction.
Classic pop-ups use flat gray rounded backgrounds sized to their options, and checkboxes use
small gray rounded squares. Native slider tracks retain macOS blue.

## Shared components

| Component | Purpose |
|---|---|
| `Card` | Heading and grouped settings surface; outlined box in Classic |
| `SectionHeader` | Section title |
| `FilledButtonStyle` | Primary action, including disabled and pressed states |
| `TonalButtonStyle` | Secondary action; supports destructive actions |
| `TextButtonStyle` | Low-emphasis action |
| `SegmentedControl` | Mutually exclusive choices |
| `UtilityPicker` | Native picker in Modern; flat gray menu in Classic |
| `ProgressBar` | Determinate progress |
| `Chip` | Counts and status |
| `HairlineDivider` | Internal separator |
| `SettingRow` | Label and control alignment |
| `InfoButton` | Help popover and tooltip |
| `ValueTag` | Fixed-width slider readout |
| `.roundedField()` | Text-field fill and focus ring |
| `.panel()` | Ad hoc preview or list surface |
| `.topDivider()` | Major region separator |
| `.materialControls()` | Accent tint and theme-specific toggle style |

Use native SwiftUI pickers, sliders, and toggles. Prefer one filled primary action in each region.
Keep icon-only actions accessible with tooltips and mark selected navigation rows and segments
with the selected accessibility trait.

## Theme updates and verification

Palette lookups are computed from persisted preferences. Top-level views observe `ThemeStore`
and re-key with `.id(theme.identity)` so style and accent changes reach the full view tree.
Every scene root needs `.materialControls()` and `.appAppearance(_:)` with the selected color
scheme. The latter updates both SwiftUI and the native window appearance so AppKit selectors
also switch between light and dark. Pass `nil` for System to retain automatic macOS changes.

Build after changing shared controls or layout. Review Modern in light and dark appearances,
wide and narrow windows, and different media operations. Review Classic after changing shared
components, including its square outlines and selected controls. Avoid changing media processing
or persisted conversion settings as part of visual work.
