/// Tour data models — Dart port of the web app's `funnelSteps.ts` and
/// `tourData.ts`. Defines the global cross-page onboarding funnel (FUNNEL_STEPS)
/// and the per-page "?" help guides (PAGE_TOURS / TOURS).
library;

/// A single step in the global onboarding funnel.
class FunnelStep {
  final String id;

  /// Registry id of the widget to spotlight (matches a [TourTarget] id).
  final String targetId;

  /// Route path this step belongs to.
  final String route;
  final String title;
  final String text;
  final String actionHint;
  final String? fallbackErrorMsg;
  final bool requireAction;

  /// When true, tapping the spotlighted element auto-advances the tour.
  /// Set ONLY for pure button steps (navigate, save, spin, start session).
  final bool clickAdvances;
  final bool hideNextButton;
  final String side; // 'left' | 'right'

  const FunnelStep({
    required this.id,
    required this.targetId,
    required this.route,
    required this.title,
    required this.text,
    required this.actionHint,
    this.fallbackErrorMsg,
    this.requireAction = false,
    this.clickAdvances = false,
    this.hideNextButton = false,
    this.side = 'left',
  });
}

const List<FunnelStep> kFunnelSteps = [
  // ── PHASE 1 — Strategy Library ──
  FunnelStep(
    id: 'lib_welcome',
    targetId: 'funnel-new-strategy',
    route: '/strategies',
    title: 'Welcome to Junko Bodie',
    text:
        'Welcome! I\'m your guide for this walkthrough. We\'re going to build a complete roulette strategy from scratch, debug it live, and run a full simulation. Tap "+ New Strategy" to begin!',
    actionHint: 'Tap the "+ New Strategy" button to open the Strategy Builder',
    fallbackErrorMsg: 'Please tap "+ New Strategy" to proceed to the Builder.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),

  // ── PHASE 2 — Strategy Builder: Profile ──
  FunnelStep(
    id: 'builder_name',
    targetId: 'funnel-strategy-name',
    route: '/strategies/build',
    title: 'Strategy Name',
    text:
        'Welcome to the Strategy Builder! Start by giving your strategy a unique name in the "Strategy Name" field. This is required and is how it will appear in your library.',
    actionHint: 'Type a custom strategy name, then tap Next',
    fallbackErrorMsg:
        'Please type a custom name for your strategy before continuing.',
    requireAction: true,
    side: 'right',
  ),
  FunnelStep(
    id: 'builder_wheel',
    targetId: 'funnel-wheel-type',
    route: '/strategies/build',
    title: 'Wheel Type',
    text:
        'Select your Wheel Type from the three available choices: American (0, 00), European (Single 0), or Both. Different formats modify house edge and betting layout options.',
    actionHint: 'Choose American, European, or Both, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'builder_description',
    targetId: 'funnel-description',
    route: '/strategies/build',
    title: 'Description (Optional)',
    text:
        'The Description field is optional — use it to note your strategy\'s intent or approach. You can leave it blank and tap Next to continue.',
    actionHint: 'Add an optional description or tap Next to skip',
    side: 'right',
  ),

  // ── PHASE 3 — Strategy Builder: Chips & Bets ──
  FunnelStep(
    id: 'builder_chip',
    targetId: 'funnel-chip-selector',
    route: '/strategies/build',
    title: 'Select Chip Value',
    text:
        'Now look at the chip tray below the roulette table. Select a chip denomination — \$1, \$5, \$25, or \$100. This is the value placed each time you tap a position on the board.',
    actionHint: 'Tap a chip denomination from the chip tray, then tap Next',
    fallbackErrorMsg: 'Please select a chip denomination from the tray first.',
    requireAction: true,
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_select_group',
    targetId: 'funnel-tag-system',
    route: '/strategies/build',
    title: 'Group Tagging (Optional)',
    text:
        'Group Tags (A, B, C…) are *optional* tools for advanced strategies. They group bets so specific bets can be added, removed, increased, or repeated as events occur. Tap "G-A" to select Group A before placing those bets.',
    actionHint: 'Optionally tap "G-A" to tag bets, or tap Next to proceed',
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_place_bet',
    targetId: 'funnel-betting-board',
    route: '/strategies/build',
    title: 'Place Your First Bet',
    text:
        'Now tap any position on the roulette table to place your chip. Try a classic like "Red", "1st 12", or a specific number like 17. You can place 2 to 3 bets for Stage 1!',
    actionHint: 'Tap positions on the roulette table, then tap Next',
    fallbackErrorMsg:
        'Please place at least one bet on the roulette board before continuing.',
    requireAction: true,
    side: 'left',
  ),

  // ── PHASE 4 — Strategy Builder: Rules & Notes ──
  FunnelStep(
    id: 'builder_rules',
    targetId: 'funnel-stage-rules',
    route: '/strategies/build',
    title: 'Stage Progression Rules',
    text:
        'These two dropdowns control how your strategy advances. "If Spin Loses" determines the next stage on a loss. "If Spin Wins" determines what happens on a win. Explore these rules and adjust if desired.',
    actionHint: 'Review or adjust win/loss stage rules, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_dynamic_rule',
    targetId: 'funnel-dynamic-rules-btn',
    route: '/strategies/build',
    title: 'Add a Dynamic Rule',
    text:
        'Dynamic Rules unlock powerful advanced conditions. Tap "Add Dynamic Rule" to add one now, such as: Condition "On Any Spin" → Action "Advance Stage".',
    actionHint: 'Tap "Add Dynamic Rule" to explore dynamic conditions, then tap Next',
    fallbackErrorMsg:
        'Please tap "Add Dynamic Rule" to add at least one dynamic rule.',
    requireAction: true,
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_notes',
    targetId: 'strategy-notes',
    route: '/strategies/build',
    title: 'Strategy Notes',
    text:
        'The Strategy Notes area is where you can document your approach, testing tips, or custom modifications. This is optional — add notes or tap Next to continue.',
    actionHint: 'Add optional notes about your strategy, then tap Next',
    side: 'right',
  ),

  // ── PHASE 5 — Strategy Builder: Multiple Stages ──
  FunnelStep(
    id: 'builder_add_stage',
    targetId: 'funnel-add-stage',
    route: '/strategies/build',
    title: 'Multi-Stage Strategies',
    text:
        'Multi-stage progressions are where the real power lies. Strategies support up to 30 distinct stages — each with its own customized bets, chip sizes, and rules. Tap "+ Add Stage" to create Stage 2!',
    actionHint: 'Tap "+ Add Stage" in the stage tabs bar to create Stage 2',
    fallbackErrorMsg: 'Please tap "+ Add Stage" to create a second stage.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_toolbar_info',
    targetId: 'table-toolbar',
    route: '/strategies/build',
    title: 'Table Shortcuts & Repeat',
    text:
        'These 4 buttons are your table shortcuts: "Repeat" copies the prior stage\'s exact bets onto this stage. "2X" doubles all bet amounts. "Undo" reverses the last action. "Clear" wipes the board clean.',
    actionHint: 'Review the toolbar shortcuts (Repeat, 2X, Undo, Clear), then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_stage2_bet',
    targetId: 'funnel-betting-board',
    route: '/strategies/build',
    title: 'Place Stage 2 Bets',
    text:
        'You\'re now configuring Stage 2. Tags and stage rules allow the strategy to adjust bets logically between stages. Tap "Repeat" to instantly copy your Stage 1 bets, or select chips below and place custom bets on the table. When finished, tap Next.',
    actionHint: 'Tap Repeat to copy bets or place chips on the table, then tap Next',
    fallbackErrorMsg:
        'Please place at least one bet for Stage 2 (or tap Repeat) before continuing.',
    requireAction: true,
    side: 'right',
  ),
  FunnelStep(
    id: 'builder_stage2_rules',
    targetId: 'funnel-stage-rules',
    route: '/strategies/build',
    title: 'Stage Rules Configuration',
    text:
        'Every stage that is created will also require entries made to the rules section. Rules may vary from stage to stage depending upon player intentions and spin outcomes — for example, whether Stage 2 resets to Stage 1 on a win or escalates further on a loss.',
    actionHint: 'Review or customize Stage 2 rules, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_add_stage3',
    targetId: 'funnel-add-stage',
    route: '/strategies/build',
    title: 'Add a Third Stage',
    text:
        'Let\'s add one more stage — 3-stage strategies provide rich data for the simulation engine. Tap "+ Add Stage" again to add Stage 3!',
    actionHint: 'Tap "+ Add Stage" again to create Stage 3',
    fallbackErrorMsg: 'Please tap "+ Add Stage" to create a third stage.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_stage3_bet',
    targetId: 'funnel-betting-board',
    route: '/strategies/build',
    title: 'Place Stage 3 Bets',
    text:
        'Stage 3 is your escalation stage. You can use "Repeat" to copy Stage 2 bets and then "2X" to double them — a classic Martingale escalation pattern. Or design your own layout!',
    actionHint: 'Place bets for Stage 3 — try the Repeat or 2X shortcuts, then tap Next',
    fallbackErrorMsg:
        'Please place at least one bet for Stage 3 before continuing.',
    requireAction: true,
    side: 'right',
  ),

  // ── PHASE 6 — Save & Navigate to Debugger ──
  FunnelStep(
    id: 'builder_save',
    targetId: 'funnel-save-strategy',
    route: '/strategies/build',
    title: 'Save Your Strategy',
    text:
        'Your 3-stage strategy is ready! Tap "SAVE STRATEGY" to save it into your library database.',
    actionHint: 'Tap the "SAVE STRATEGY" button',
    fallbackErrorMsg:
        'Please tap "SAVE STRATEGY" to save your strategy before continuing.',
    requireAction: true,
    side: 'left',
  ),
  FunnelStep(
    id: 'builder_navigator',
    targetId: 'funnel-goto-navigator',
    route: '/strategies/build',
    title: 'Launch the Debugger',
    text:
        'Strategy saved! Now let\'s test it spin-by-spin in the live Debugger. Tap "NAVIGATOR" to open the Debugger with your strategy pre-loaded.',
    actionHint: 'Tap "NAVIGATOR" in the top bar',
    fallbackErrorMsg: 'Please tap "NAVIGATOR" to open the Debugger.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),

  // ── PHASE 7 — Debugger: Session Setup & Spin ──
  FunnelStep(
    id: 'debug_select_strategy',
    targetId: 'select-strategy',
    route: '/strategies/debug',
    title: 'Strategy Selector',
    text:
        'Your strategy is pre-selected in the dropdown. The Debugger lets you simulate your strategy one spin at a time so you can observe the engine\'s exact logic.',
    actionHint: 'Confirm your strategy is selected, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'debug_bankroll',
    targetId: 'bankroll-config',
    route: '/strategies/debug',
    title: 'Starting Bankroll',
    text:
        'Set your Starting Bankroll. We\'ll use \$500 so you can clearly see drawdowns, profit banking, and stage transitions interact.',
    actionHint: 'Review Starting Bankroll and Bank Profits, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'debug_session_entry',
    targetId: 'session-entry-rule',
    route: '/strategies/debug',
    title: 'Session Entry Rule',
    text:
        'Session Entry determines when betting begins. *Tap this dropdown* to choose a mode: "Start Betting Immediately" places bets on spin 1, while "Wait for X Phantom Misses" observes the table until a streak of losses occurs before placing real chips. Selecting the phantom-misses option reveals a new field just below where you set how many misses to wait for.',
    actionHint: 'Tap the dropdown to pick an entry mode, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'debug_start',
    targetId: 'funnel-start-debug',
    route: '/strategies/debug',
    title: 'Start Debug Session',
    text:
        'Tap "Start Debug Session" to initialize the spin engine with your strategy and bankroll. This loads all your stages, bets, and rules into the live debugger.',
    actionHint: 'Tap the "Start Debug Session" button',
    fallbackErrorMsg: 'Please tap "Start Debug Session" to initialize the engine.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'right',
  ),
  FunnelStep(
    id: 'debug_force_number',
    targetId: 'funnel-force-result',
    route: '/strategies/debug',
    title: 'Force a Specific Result (Optional)',
    text:
        'This one is *optional* and seldom used. If you ever want to test an exact outcome, type a wheel number (such as "17") in the "Force Spin Result" box to force it. Otherwise just leave it blank for a random spin and tap Next.',
    actionHint: 'Optionally force a number, or tap Next to use a random spin',
    requireAction: false,
    side: 'left',
  ),
  FunnelStep(
    id: 'debug_spin',
    targetId: 'funnel-spin-button',
    route: '/strategies/debug',
    title: 'Execute the Spin',
    text:
        'Tap "SPIN" to execute the spin! The engine will process the result through your Stage 1 bets and calculate wins, losses, and stage transitions.',
    actionHint: 'Tap "SPIN" to run the spin',
    fallbackErrorMsg: 'Please tap "SPIN" to execute the spin.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),
  FunnelStep(
    id: 'debug_read_log',
    targetId: 'spin-log',
    route: '/strategies/debug',
    title: 'Read the Spin Log',
    text:
        'Look at the Spin Log! Each row shows: spin number, the result, net profit/loss on that spin, engine action (Win / Loss), and running bankroll. This is your strategy\'s math laid out spin by spin.',
    actionHint: 'Review the Spin Log output, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'debug_live_metrics',
    targetId: 'live-metrics',
    route: '/strategies/debug',
    title: 'Live KPI Dashboard',
    text:
        'These KPI tiles update after every spin: Bankroll, Session P&L, Total Banked Profit, Active Stage, and Total Spins. Watch these while you spin!',
    actionHint: 'Review the live metrics panel, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'debug_to_sim',
    targetId: 'funnel-simulate-btn',
    route: '/strategies/debug',
    title: 'Move to Simulator',
    text:
        'Excellent! You\'ve seen how the engine processes each spin. Now let\'s run thousands of spins to get statistically meaningful grades and performance data. Tap "Test in Simulator"!',
    actionHint: 'Tap "Test in Simulator" to open the Simulation page',
    fallbackErrorMsg:
        'Please tap "Test in Simulator" to continue to the Simulation page.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),

  // ── PHASE 8 — Simulation Setup ──
  FunnelStep(
    id: 'sim_strategy_select',
    targetId: 'sim-strategy-select',
    route: '/simulation/setup',
    title: 'Strategy Selection',
    text:
        'Your strategy from the lab is pre-selected. You can also pick any other saved strategy to backtest against massive sample sizes.',
    actionHint: 'Confirm strategy selection, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'sim_entry_rule',
    targetId: 'sim-entry-rule',
    route: '/simulation/setup',
    title: 'Session Entry Trigger',
    text:
        '*Tap this dropdown* to choose whether sessions bet immediately on spin 1, or wait and observe the wheel until a required number of phantom misses occur before betting. If you pick "Wait for Specific Misses", a field appears just below where you set the exact number of phantom misses to wait for.',
    actionHint: 'Tap the dropdown to pick an entry trigger, then tap Next',
    side: 'right',
  ),
  FunnelStep(
    id: 'sim_spins_config',
    targetId: 'sim-spins-config',
    route: '/simulation/setup',
    title: 'Target Sample Size (100 Spins)',
    text:
        'Set your requested spin limit (defaults to 100 spins). 100 spins simulates a focused "Hit and Run" session playing style. You can also test up to 25,000 spins anytime for deep long-term statistical stress-testing!',
    actionHint: 'Review requested spins (default 100), then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'sim_bankroll_config',
    targetId: 'sim-bankroll-config',
    route: '/simulation/setup',
    title: 'Bankroll & Compounding',
    text:
        'Configure your starting bankroll (\$5,000) and choose whether profits compound continuously across all spins or reset per session.',
    actionHint: 'Review bankroll configuration, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'sim_run',
    targetId: 'funnel-run-simulation',
    route: '/simulation/setup',
    title: 'Execute Simulation',
    text:
        'All parameters configured! Tap "EXECUTE ENGINE" to launch the high-speed Monte Carlo simulation engine. Results will generate in seconds.',
    actionHint: 'Tap the "EXECUTE ENGINE" button',
    fallbackErrorMsg: 'Please tap "EXECUTE ENGINE" to run the backtest.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),

  // ── PHASE 9 — Simulation Results Dashboard ──
  FunnelStep(
    id: 'sim_grade',
    targetId: 'funnel-grade-card',
    route: '/simulation/run',
    title: 'General Overview & System Grade',
    text:
        'General Overview provides a grade for your system using the parameters you submitted. The less dips in bankroll trajectory the better your system. The system\'s P&L and number of sessions for your selected number of spins are also critical information. This screen provides a baseline for system success.',
    actionHint: 'Review your strategy\'s Casino Grade and Junko\'s Tip, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'sim_profitability',
    targetId: 'funnel-profit-dynamics',
    route: '/simulation/run',
    title: 'Profitability Dynamics',
    text:
        'Junko considers this to be the key screen when determining if a roulette system has potential. The Profitability Stats tell a story.',
    actionHint: 'Tap the "Profitability Dynamics" tab and review the stats, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'sim_chart',
    targetId: 'funnel-bankroll-stability',
    route: '/simulation/run',
    title: 'Bankroll Stability',
    text:
        'Bankroll management is the key to successful gaming. *Tap the "Bankroll Stability" tab* to view the equity trajectory. If your strategy has too many large dips, profitability will suffer. This is where you visualize your system\'s vulnerabilities or prove that it is ready for prime time.',
    actionHint: 'Tap the "Bankroll Stability" tab to view the chart, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'sim_stage_penetration',
    targetId: 'funnel-stage-penetration',
    route: '/simulation/run',
    title: 'Stage Penetration',
    text:
        '*Tap the "Stage Penetration" tab* to open this breakdown. It shows how deep your strategy progressed during the simulation — how often each stage was reached, so you can see whether your system typically resolves early or frequently advances into its later stages. The deeper it penetrates, the greater the pressure on your bankroll.',
    actionHint: 'Tap the "Stage Penetration" tab to view the breakdown, then tap Next',
    side: 'left',
  ),
  FunnelStep(
    id: 'sim_return',
    targetId: 'funnel-return-library',
    route: '/simulation/run',
    title: 'Return to Library',
    text:
        'Tour complete! You have learned how to build a multi-stage strategy, debug it live, and analyze its simulation results. Tap "Return to Strategy Library" to finish your onboarding.',
    actionHint: 'Tap "Return to Strategy Library" to complete the tour',
    fallbackErrorMsg:
        'Please tap "Return to Strategy Library" to complete your tour.',
    requireAction: true,
    clickAdvances: true,
    hideNextButton: true,
    side: 'left',
  ),

  // ── PHASE 10 — Graduation ──
  FunnelStep(
    id: 'lib_graduation',
    targetId: 'funnel-graduation-card',
    route: '/strategies',
    title: 'Onboarding Complete',
    text:
        'You have completed the full Junko Bodie walkthrough! You are now ready to build, test, and deploy your own betting systems. Your strategy lives in the library — keep building, testing, and refining. Good luck at the table.',
    actionHint: 'Tap Finish to complete your tour',
    side: 'left',
  ),
];

/// A single step in a per-page help guide.
class TourStep {
  final String id; // matches a [TourTarget] id
  final String text;
  final String? side; // 'left' | 'right'
  final bool requireAdmin;

  const TourStep({
    required this.id,
    required this.text,
    this.side,
    this.requireAdmin = false,
  });
}

class TourDefinition {
  final String id;
  final String storageKey;
  final List<TourStep> steps;
  final String side;

  const TourDefinition({
    required this.id,
    required this.storageKey,
    required this.steps,
    this.side = 'left',
  });
}

/// Per-page "?" help guides, keyed by a short tour id.
/// Mirrors the web `TOURS` map in `tourData.ts`.
const Map<String, TourDefinition> kPageTours = {
  'library': TourDefinition(
    id: 'library',
    storageKey: 'junko_tour_library_completed',
    steps: [
      TourStep(
        id: 'back-to-lobby',
        text: 'Hey! Tap here anytime you want to head back to the main lobby.',
      ),
      TourStep(
        id: 'header-actions',
        text:
            "These are your control center — Show Hidden brings back anything you've archived, and + New Strategy starts one from scratch.",
      ),
      TourStep(
        id: 'strategy-card',
        text:
            'Every strategy shows up as a card like this one — wheel type, stage count, and a quick note on how it plays. Tap anywhere on it to open it up.',
      ),
      TourStep(
        id: 'card-actions',
        text:
            'Down here are your shortcuts — the pulse icon jumps into testing, the pencil edits it, the eye hides it from view, and the trash deletes it for good.',
      ),
    ],
  ),
  'builder': TourDefinition(
    id: 'builder',
    storageKey: 'junko_tour_builder_completed',
    steps: [
      TourStep(
        id: 'builder-top-nav',
        text:
            "Don't forget to hit Save when you're happy with things — Navigator lets you test it right away.",
      ),
      TourStep(
        id: 'builder-sidebar',
        text:
            'Name your strategy, pick American or European wheel, add a short description, and set how many stages it can have.',
      ),
      TourStep(
        id: 'stage-tabs',
        text:
            'Every strategy is built in stages — tap a tab to jump to one, or hit + Add Stage to add another step.',
      ),
      TourStep(
        id: 'table-toolbar',
        text:
            "These save you time — Repeat copies your last stage's bets, 2x Double doubles every chip, and Undo/Clear fix mistakes fast.",
      ),
      TourStep(
        id: 'funnel-betting-board',
        text:
            'Pick a chip value below, then tap anywhere on the table to place a bet — go on, try it!',
      ),
      TourStep(
        id: 'funnel-tag-system',
        text:
            'Want a few bets grouped together? Pick a tag letter, then tap your chips — tagged bets can be removed together later.',
      ),
      TourStep(
        id: 'funnel-stage-rules',
        text:
            'This is the heart of it — tell your strategy what to do when it wins, and what to do when it loses.',
      ),
      TourStep(
        id: 'funnel-dynamic-rules-btn',
        text:
            'Feeling advanced? Build custom rules here — like clearing your winning bets automatically, or doubling up after a loss.',
      ),
      TourStep(
        id: 'strategy-notes',
        text:
            "Last thing — leave yourself a note here so you remember exactly how this one's meant to be played.",
      ),
    ],
  ),
  'debugger': TourDefinition(
    id: 'debugger',
    storageKey: 'junko_tour_debugger_completed',
    steps: [
      TourStep(
        id: 'select-strategy',
        text: 'First, pick which strategy you want to put to the test.',
      ),
      TourStep(
        id: 'bankroll-config',
        text:
            "Set how much you're starting with — and check this box if you'd rather bank your profit and reset back to your starting balance each session.",
      ),
      TourStep(
        id: 'session-entry-rule',
        text: 'Want to jump in right away, or wait for a few misses first? Your call.',
      ),
      TourStep(
        id: 'funnel-force-result',
        text:
            'Curious how your strategy handles one specific number? Type it in here — or leave it blank for a random spin.',
      ),
      TourStep(
        id: 'funnel-spin-button',
        text: 'Ready? Hit Spin to execute a spin.',
      ),
      TourStep(
        id: 'live-metrics',
        text:
            "Keep an eye on these — your bankroll, profit, current stage, and how many spins you've run.",
      ),
      TourStep(
        id: 'spin-log',
        text:
            'Every spin gets logged here, so you can scroll back and see exactly what happened and why.',
      ),
    ],
  ),
  'simulation-setup': TourDefinition(
    id: 'simulation-setup',
    storageKey: 'junko_tour_sim_setup_completed',
    steps: [
      TourStep(
        id: 'sim-strategy-select',
        text: 'Select the strategy you want to backtest across thousands of spins.',
      ),
      TourStep(
        id: 'sim-entry-rule',
        text: 'Configure immediate betting or phantom missed spin thresholds.',
      ),
      TourStep(
        id: 'sim-spins-config',
        text:
            'Set your simulation depth — up to 25,000 spins for statistical significance.',
      ),
      TourStep(
        id: 'sim-bankroll-config',
        text: 'Set starting bankroll and enable/disable session balance resetting.',
      ),
      TourStep(
        id: 'funnel-run-simulation',
        text: 'Tap "Execute Engine" to start the simulation.',
      ),
    ],
  ),
  'simulation-run': TourDefinition(
    id: 'simulation-run',
    storageKey: 'junko_tour_sim_run_completed',
    steps: [
      TourStep(
        id: 'funnel-grade-card',
        text:
            'Instant institutional letter grade (A to F) based on risk-adjusted ROI and survival rate.',
      ),
      TourStep(
        id: 'funnel-profit-dynamics',
        text:
            'Comprehensive metrics including Profit Factor, Win/Loss Rate, Max Drawdown, and Session Efficiency.',
      ),
      TourStep(
        id: 'funnel-bankroll-chart',
        text:
            'Equity curve visualizing bankroll growth or decline across all simulated spins.',
      ),
      TourStep(
        id: 'funnel-return-library',
        text:
            'Return to your Strategy Library or view past backtesting runs in Simulation History.',
      ),
    ],
  ),
};
