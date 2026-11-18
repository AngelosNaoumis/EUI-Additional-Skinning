# LagBuddy

## Scope

The installed LagBuddy 1.0.5 source was inspected. The active settings analysis is the Graphics
view inside `LagBuddyMainFrame`; `/lb settings` selects that view rather than creating a separate
window. The skin covers that main window and the lazy `LagBuddyCaptureResultsFrame`. It also safely
handles `LagBuddyGameSettingsFrame` if the addon's currently dormant compatibility constructor is
invoked. The full-screen modal dim layers and minimap launcher are functional support surfaces and
are intentionally left native.

The main frame is created at `PLAYER_LOGIN`; the results dialog is created by its slash/button or
automatic-completion action. Those structural lifecycle points queue a one-time walk of each new
window. Manual results are observed from their button click and automatic results from that
button's enable transition. The
skin never hooks LagBuddy's profiler, metric sampling, row refresh, countdown, graph/data logic,
scrolling, or any `OnUpdate` path.

Window shells, ordinary text buttons, fonts, scroll bars and present controls use the shared EUI
primitives. LagBuddy's custom monitoring toggle, integrated Addons/Graphics tabs, analysis banner
and content panels keep their state colors and behavior while their thick tooltip backdrops are
reduced to the project's flat one-pixel panel edge.

The `LagBuddy` master toggle is on by default. No component sub-options are exposed because the
analyzer and its results surface form one UI and their stateful panels must keep a consistent
visual treatment.

## History

- 2.3.0: added analyzer, settings-view, and results-dialog skinning.
