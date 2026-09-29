import type { GameCommand, GameState } from '../simulation';
import './styles.css';

type InterfaceCallbacks = {
  onCommand(command: GameCommand): void;
  onSave(): void;
  onLoad(): void;
  onReset(): void;
  onMotion(enabled: boolean): void;
};

type Page = 'overview' | 'production' | 'ledger' | 'settings';
const money = (value: number) => `$${value.toLocaleString('en-US')}`;

/** A stable DOM shell. Only values change on simulation ticks, preserving focus. */
export function createInterface(root: HTMLElement, callbacks: InterfaceCallbacks) {
  root.innerHTML = `
    <div class="game-shell">
      <a class="skip-link" href="#main-content">Skip to workshop</a>
      <header class="masthead">
        <a class="wordmark" href="#" aria-label="Yard overview"><span class="brand-mark" aria-hidden="true"><i></i><i></i><i></i></span>YARD<span class="wordmark-slash">/</span></a>
        <div class="masthead-description">WORKSHOP SIMULATOR<span>A small operation. Room to grow.</span></div>
        <span class="build-label">FRAMEWORK<br>BUILD 01</span>
      </header>
      <div class="workspace">
        <aside class="sidebar">
          <div class="sidebar-label">WORKSPACE</div>
          <nav class="navigation" aria-label="Workshop sections">
            <button type="button" data-page="overview" aria-current="page"><span class="nav-number" aria-hidden="true">01</span>Overview<span class="nav-arrow" aria-hidden="true">↗</span></button>
            <button type="button" data-page="production"><span class="nav-number" aria-hidden="true">02</span>Production<span class="nav-arrow" aria-hidden="true">↗</span></button>
            <button type="button" data-page="ledger"><span class="nav-number" aria-hidden="true">03</span>Ledger<span class="nav-arrow" aria-hidden="true">↗</span></button>
            <button type="button" data-page="settings"><span class="nav-number" aria-hidden="true">04</span>Settings<span class="nav-arrow" aria-hidden="true">↗</span></button>
          </nav>
          <div class="sidebar-note"><span class="tiny-label">FIELD NOTES / 001</span><p>Good work starts<br>with a small workshop.</p><div class="note-rule"></div><span class="tiny-label">BUY. MAKE. DISPATCH.</span></div>
        </aside>
        <main id="main-content" class="main-content" tabindex="-1">
          <section data-panel="overview" aria-labelledby="overview-heading">
            <div class="page-heading"><div><p class="eyebrow">YOUR OPERATION</p><h1 id="overview-heading">The workshop</h1></div><span class="status-tag" data-operation-status>STANDING BY</span></div>
            <p class="page-intro">Buy materials, put your crew to work, and sell the finished parts.</p>
            <figure class="scene-frame"><div class="scene-topline"><span>WORKSHOP / EXTERIOR</span><span class="scene-live"><span aria-hidden="true"></span><span data-scene-status>LIVE VIEW</span></span></div><canvas class="workshop-canvas" width="640" height="240" role="img" aria-label="Animated pixel art workshop. The scene is decorative; all game information is in the menus below."></canvas><figcaption><span>One workshop. Every possibility.</span><span class="scene-caption-right">EST. TODAY</span></figcaption></figure>
            <div class="resource-strip" aria-label="Workshop resources">
              <div class="resource"><span class="tiny-label">AVAILABLE FUNDS</span><strong data-value="credits">$0</strong><span class="resource-foot">Ready to invest</span></div>
              <div class="resource"><span class="tiny-label">RAW MATERIALS</span><strong data-value="materials">0</strong><span class="resource-foot">Units in storage</span></div>
              <div class="resource"><span class="tiny-label">FINISHED PARTS</span><strong data-value="goods">0</strong><span class="resource-foot">Ready for dispatch</span></div>
              <div class="resource"><span class="tiny-label">WORKSHOP CREW</span><strong><span data-value="workers">0</span><span class="resource-max"> / 6</span></strong><span class="resource-foot">Workers on site</span></div>
            </div>
            <div class="overview-grid"><section class="panel" aria-labelledby="operations-heading"><div class="panel-heading"><h2 id="operations-heading">Workshop operations</h2><span class="tiny-label">CONTROL DESK</span></div>
              <div class="production-row"><div><span class="field-title">Production line</span><span class="field-note" data-production-note>Choose a job to start making parts.</span></div><div class="segmented" aria-label="Production mode"><button type="button" data-production="idle" aria-pressed="true">Idle</button><button type="button" data-production="parts" aria-pressed="false">Make parts</button></div></div>
              <div class="operation-actions"><button class="action-button" type="button" data-command="buy-materials"><span>Buy materials <small>+10 units</small></span><span>$30<span aria-hidden="true"> ↗</span></span></button><button class="action-button" type="button" data-command="sell-goods"><span>Dispatch parts <small data-sale-count>None ready</small></span><span data-sale-value>$0 ↗</span></button><button class="action-button" type="button" data-command="hire-worker"><span>Hire a worker <small data-hire-note>Expand your crew</small></span><span>$100<span aria-hidden="true"> ↗</span></span></button></div>
            </section><section class="panel log-panel" aria-labelledby="log-heading"><div class="panel-heading"><h2 id="log-heading">Dispatch log</h2><span class="tiny-label">LATEST ACTIVITY</span></div><ol class="activity-log" data-log="short"><li class="empty-log">Your workshop's story starts here.</li></ol><div class="log-footer">Small steps. Steady progress.</div></section></div>
          </section>
          <section data-panel="production" aria-labelledby="production-heading" hidden>
            <div class="page-heading"><div><p class="eyebrow">MAKE SOMETHING USEFUL</p><h1 id="production-heading">Production</h1></div><span class="status-tag" data-operation-status>STANDING BY</span></div><p class="page-intro">Keep materials on hand and choose when your crew gets to work.</p>
            <section class="panel production-detail"><div class="panel-heading"><h2>Parts assembly</h2><span class="tiny-label">LINE 01</span></div><div class="process-diagram" aria-label="Materials become finished parts through crew production"><div><span class="tiny-label">INPUT</span><strong data-value="materials">0</strong><span>Raw materials</span></div><span class="process-arrow" aria-hidden="true">→</span><div><span class="tiny-label">WORKFORCE</span><strong data-value="workers">0</strong><span>Workshop crew</span></div><span class="process-arrow" aria-hidden="true">→</span><div><span class="tiny-label">OUTPUT</span><strong data-value="goods">0</strong><span>Finished parts</span></div></div><div class="production-row"><div><span class="field-title">Line status</span><span class="field-note" data-production-note>Choose a job to start making parts.</span></div><div class="segmented" aria-label="Production mode"><button type="button" data-production="idle" aria-pressed="true">Idle</button><button type="button" data-production="parts" aria-pressed="false">Make parts</button></div></div><div class="detail-actions"><button class="button primary" type="button" data-command="buy-materials">Buy 10 materials · $30</button><button class="button" type="button" data-command="hire-worker">Hire worker · $100</button></div></section>
            <div class="information-note"><span class="tiny-label">WORKSHOP NOTES</span><p>Production uses stored materials. If supplies run out, the line waits until you restock. Pause or change the simulation speed using the controls below.</p></div>
          </section>
          <section data-panel="ledger" aria-labelledby="ledger-heading" hidden><div class="page-heading"><div><p class="eyebrow">KEEP THE BOOKS</p><h1 id="ledger-heading">The ledger</h1></div><span class="status-tag">CURRENT POSITION</span></div><p class="page-intro">A clear view of your cash, inventory, and workshop activity.</p>
            <div class="ledger-grid"><section class="panel"><div class="panel-heading"><h2>On the books</h2><span class="tiny-label">INVENTORY</span></div><dl class="balance-sheet"><div><dt>Available funds</dt><dd data-value="credits">$0</dd></div><div><dt>Materials on hand</dt><dd><span data-value="materials">0</span> units</dd></div><div><dt>Finished parts</dt><dd><span data-value="goods">0</span> units</dd></div><div class="balance-total"><dt>Parts sale value</dt><dd data-value="inventoryValue">$0</dd></div></dl><div class="detail-actions"><button class="button primary" type="button" data-command="sell-goods">Sell all finished parts</button></div></section><section class="panel"><div class="panel-heading"><h2>Rate card</h2><span class="tiny-label">FIXED PRICES</span></div><dl class="balance-sheet"><div><dt>10 raw materials</dt><dd>$30</dd></div><div><dt>1 finished part</dt><dd>$12</dd></div><div><dt>1 additional worker</dt><dd>$100</dd></div><div><dt>Maximum crew</dt><dd>6 workers</dd></div></dl></section></div>
            <section class="panel ledger-history"><div class="panel-heading"><h2>Activity record</h2><span class="tiny-label">RECENT EVENTS</span></div><ol class="activity-log" data-log="full"></ol></section>
          </section>
          <section data-panel="settings" aria-labelledby="settings-heading" hidden><div class="page-heading"><div><p class="eyebrow">MAKE YOURSELF AT HOME</p><h1 id="settings-heading">Settings</h1></div></div><p class="page-intro">Manage your workshop save and set the scene to your liking.</p>
            <section class="panel settings-panel"><div class="panel-heading"><h2>Your workshop</h2><span class="tiny-label">LOCAL SAVE</span></div><div class="settings-row"><div><h3>Save your progress</h3><p>Keep a snapshot in this browser, then return to it later.</p></div><div class="settings-buttons"><button class="button primary" type="button" data-action="save">Save game</button><button class="button" type="button" data-action="load">Load game</button></div></div><div class="settings-row"><div><h3>Background animation</h3><p>Decorative movement in the workshop scene.</p></div><label class="checkbox-label"><input type="checkbox" data-action="motion">Enable motion</label></div><div class="settings-row"><div><h3>Start a new workshop</h3><p>Reset the current run to its starting state.</p></div><button class="button" type="button" data-action="request-reset">New game</button></div><div class="reset-confirmation" hidden><p>Start fresh? Your current workshop will be reset.</p><div class="settings-buttons"><button class="button danger" type="button" data-action="confirm-reset">Yes, start fresh</button><button class="button" type="button" data-action="cancel-reset">Keep this workshop</button></div></div></section>
            <div class="information-note"><span class="tiny-label">ABOUT THIS BUILD</span><p>YARD is a working foundation for a menu-driven simulation. The workshop is a small sample loop, ready to grow into your game.</p></div>
          </section>
          <div class="notification" role="status" aria-live="polite" aria-atomic="true"></div>
        </main>
      </div>
      <footer class="statusbar"><div class="clock-readout"><span class="clock-dot" aria-hidden="true"></span><span data-clock-status>RUNNING</span><span class="status-divider" aria-hidden="true">/</span><span>TICK <span data-value="tick">0000</span></span></div><div class="speed-controls" aria-label="Simulation speed"><span class="tiny-label">TIME CONTROL</span><div class="segmented"><button type="button" data-speed="0" aria-label="Pause simulation" aria-pressed="false">Ⅱ</button><button type="button" data-speed="1" aria-label="Normal speed" aria-pressed="true">1×</button><button type="button" data-speed="2" aria-label="Double speed" aria-pressed="false">2×</button><button type="button" data-speed="4" aria-label="Quadruple speed" aria-pressed="false">4×</button></div></div></footer>
    </div>`;

  const select = <T extends HTMLElement>(query: string) => root.querySelector<T>(query)!;
  const all = <T extends HTMLElement>(query: string) => Array.from(root.querySelectorAll<T>(query));
  const canvas = select<HTMLCanvasElement>('canvas');
  const notification = select('.notification');
  const confirmation = select('.reset-confirmation');
  const motion = select<HTMLInputElement>('[data-action="motion"]');
  const abort = new AbortController();
  const media = window.matchMedia('(prefers-reduced-motion: reduce)');
  let motionChangedByUser = false;
  let lastLog = '';
  let noticeTimer: ReturnType<typeof setTimeout> | undefined;

  function showPage(page: Page) {
    all('[data-panel]').forEach(panel => { panel.hidden = panel.dataset.panel !== page; });
    all('[data-page]').forEach(button => {
      if (button.dataset.page === page) button.setAttribute('aria-current', 'page');
      else button.removeAttribute('aria-current');
    });
    confirmation.hidden = true;
  }
  function updateMotion(enabled: boolean) {
    motion.checked = enabled;
    select('[data-scene-status]').textContent = enabled ? 'LIVE VIEW' : 'STILL VIEW';
    callbacks.onMotion(enabled);
  }
  updateMotion(!media.matches);
  media.addEventListener('change', event => {
    if (!motionChangedByUser) updateMotion(!event.matches);
  }, { signal: abort.signal });
  root.addEventListener('click', event => {
    const target = (event.target as Element).closest<HTMLElement>('button, .wordmark');
    if (!target || !root.contains(target)) return;
    if (target.classList.contains('wordmark')) { event.preventDefault(); showPage('overview'); return; }
    if (target.dataset.page) showPage(target.dataset.page as Page);
    if (target.dataset.command) callbacks.onCommand({ type: target.dataset.command } as GameCommand);
    if (target.dataset.production) callbacks.onCommand({ type: 'set-production', production: target.dataset.production as 'idle' | 'parts' });
    if (target.dataset.speed) callbacks.onCommand({ type: 'set-speed', speed: Number(target.dataset.speed) as 0 | 1 | 2 | 4 });
    switch (target.dataset.action) {
      case 'save': callbacks.onSave(); break;
      case 'load': callbacks.onLoad(); break;
      case 'request-reset': confirmation.hidden = false; select('[data-action="cancel-reset"]').focus(); break;
      case 'cancel-reset': confirmation.hidden = true; select('[data-action="request-reset"]').focus(); break;
      case 'confirm-reset': callbacks.onReset(); confirmation.hidden = true; select('[data-action="request-reset"]').focus(); break;
    }
  }, { signal: abort.signal });
  motion.addEventListener('change', () => { motionChangedByUser = true; updateMotion(motion.checked); }, { signal: abort.signal });

  function render(state: GameState) {
    const values: Record<string, string> = {
      credits: money(state.credits), materials: state.materials.toLocaleString('en-US'), goods: state.goods.toLocaleString('en-US'),
      workers: String(state.workers), tick: String(state.tick).padStart(4, '0'), inventoryValue: money(state.goods * 12),
    };
    all('[data-value]').forEach(element => { element.textContent = values[element.dataset.value!] ?? ''; });
    const status = state.production === 'idle' ? 'STANDING BY' : state.materials === 0 ? 'AWAITING MATERIALS' : state.speed === 0 ? 'SIMULATION PAUSED' : 'PRODUCTION ACTIVE';
    all('[data-operation-status]').forEach(element => { element.textContent = status; element.classList.toggle('active', state.production === 'parts' && state.materials > 0 && state.speed > 0); });
    const productionNote = state.production === 'idle' ? 'Choose a job to start making parts.' : state.materials === 0 ? 'Out of materials. Restock to continue.' : state.speed === 0 ? 'Ready to work. Resume the simulation below.' : `${state.workers} ${state.workers === 1 ? 'worker is' : 'workers are'} making parts.`;
    all('[data-production-note]').forEach(element => { element.textContent = productionNote; });
    all<HTMLButtonElement>('[data-production]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.production === state.production)));
    all<HTMLButtonElement>('[data-speed]').forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.speed) === state.speed)));
    select('[data-clock-status]').textContent = state.speed === 0 ? 'PAUSED' : 'RUNNING';
    select('.clock-dot').classList.toggle('paused', state.speed === 0);
    all<HTMLButtonElement>('[data-command]').forEach(button => {
      const command = button.dataset.command;
      button.disabled = command === 'buy-materials' ? state.credits < 30 : command === 'sell-goods' ? state.goods === 0 : state.credits < 100 || state.workers >= 6;
      button.title = !button.disabled ? '' : command === 'sell-goods' ? 'Make some parts before dispatching.' : command === 'hire-worker' && state.workers >= 6 ? 'Your crew is at capacity.' : 'More funds are needed.';
    });
    select('[data-sale-count]').textContent = state.goods === 0 ? 'None ready' : `${state.goods} ${state.goods === 1 ? 'part' : 'parts'} ready`;
    select('[data-sale-value]').textContent = `${money(state.goods * 12)} ↗`;
    select('[data-hire-note]').textContent = state.workers >= 6 ? 'Crew at capacity' : 'Expand your crew';
    const logKey = JSON.stringify(state.log);
    if (lastLog !== logKey) {
      lastLog = logKey;
      all<HTMLOListElement>('[data-log]').forEach(list => {
        const entries = [...state.log].reverse().slice(0, list.dataset.log === 'short' ? 4 : 30);
        const fragment = document.createDocumentFragment();
        entries.forEach(entry => {
          const li = document.createElement('li');
          const time = document.createElement('span'); time.className = 'log-tick'; time.textContent = `T${String(entry.tick).padStart(4, '0')}`;
          const message = document.createElement('span'); message.textContent = entry.message;
          li.append(time, message); fragment.append(li);
        });
        if (!entries.length) { const empty = document.createElement('li'); empty.className = 'empty-log'; empty.textContent = "Your workshop's story starts here."; fragment.append(empty); }
        list.replaceChildren(fragment);
      });
    }
  }

  function notify(message: string, isError = false) {
    clearTimeout(noticeTimer);
    notification.textContent = message;
    notification.classList.toggle('error', isError);
    noticeTimer = setTimeout(() => { notification.textContent = ''; }, 8000);
  }
  return { canvas, render, notify, destroy() { abort.abort(); clearTimeout(noticeTimer); root.replaceChildren(); } };
}
