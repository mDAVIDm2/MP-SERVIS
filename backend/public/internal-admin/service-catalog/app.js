(function () {
  const API = '/api/v1';
  const TOKEN_KEY = 'mp_servis_internal_token';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  let token = localStorage.getItem(TOKEN_KEY) || '';
  let filterStatus = 'all';
  let searchQ = '';
  let page = 1;
  const limit = 24;
  let listMeta = { total: 0, pages: 1 };
  let selected = null;

  function showView(name) {
    $('#view-login').hidden = name !== 'login';
    $('#view-app').hidden = name !== 'app';
  }

  function toast(msg, type = 'ok') {
    const host = $('#toast-host');
    const el = document.createElement('div');
    el.className = 'toast ' + (type === 'err' ? 'err' : 'ok');
    el.textContent = msg;
    host.appendChild(el);
    setTimeout(() => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(8px)';
      el.style.transition = '0.25s ease';
      setTimeout(() => el.remove(), 280);
    }, 4200);
  }

  async function api(path, opts = {}) {
    const headers = { ...(opts.headers || {}) };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    if (opts.body && typeof opts.body === 'object' && !(opts.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(opts.body);
    }
    const res = await fetch(API + path, { ...opts, headers });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = { raw: text };
    }
    if (res.status === 401) {
      token = '';
      localStorage.removeItem(TOKEN_KEY);
      showView('login');
      throw new Error('Сессия истекла. Войдите снова.');
    }
    if (!res.ok) {
      const msg =
        (data && (data.message || data.error)) ||
        (Array.isArray(data?.message) ? data.message.join(', ') : null) ||
        res.statusText ||
        'Ошибка запроса';
      throw new Error(typeof msg === 'string' ? msg : JSON.stringify(msg));
    }
    return data;
  }

  async function loadMe() {
    const me = await api('/internal/auth/me');
    $('#user-name').textContent = me.name || me.email;
    $('#user-email').textContent = me.email || '';
    const ini = (me.name || me.email || '?').trim().charAt(0).toUpperCase();
    $('#user-initial').textContent = ini;
  }

  async function loadStats() {
    const s = await api('/internal/service-catalog/suggestions/stats');
    $('#stat-pending').textContent = s.pending ?? 0;
    $('#stat-reviewed').textContent = s.reviewed ?? 0;
    $('#stat-total').textContent = s.total ?? 0;
  }

  function formatDate(iso) {
    if (!iso) return '—';
    try {
      const d = new Date(iso);
      return d.toLocaleString('ru-RU', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return iso;
    }
  }

  function renderList(items) {
    const grid = $('#list-grid');
    grid.innerHTML = '';
    for (const it of items) {
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'suggestion-card';
      card.dataset.id = it.id;
      const badge =
        it.status === 'reviewed'
          ? '<span class="badge badge-reviewed">Рассмотрено</span>'
          : '<span class="badge badge-pending">Ожидает</span>';
      card.innerHTML = `
        <div class="org">${escapeHtml(it.organization_name || '—')}</div>
        <div class="title">${escapeHtml(it.requested_name || '')}</div>
        <div class="meta">
          ${badge}
          <span class="mono-date">${formatDate(it.created_at)}</span>
        </div>
      `;
      card.addEventListener('click', () => openDrawer(it));
      grid.appendChild(card);
    }
  }

  function escapeHtml(s) {
    const d = document.createElement('div');
    d.textContent = s;
    return d.innerHTML;
  }

  async function loadList() {
    $('#list-loading').hidden = false;
    $('#list-empty').hidden = true;
    $('#list-grid').innerHTML = '';
    $('#pagination').hidden = true;
    try {
      const params = new URLSearchParams();
      if (filterStatus && filterStatus !== 'all') params.set('status', filterStatus);
      if (searchQ.trim()) params.set('q', searchQ.trim());
      params.set('page', String(page));
      params.set('limit', String(limit));
      const data = await api('/internal/service-catalog/suggestions?' + params.toString());
      listMeta = { total: data.total, pages: data.pages };
      $('#list-loading').hidden = true;
      if (!data.items || data.items.length === 0) {
        $('#list-empty').hidden = false;
        return;
      }
      renderList(data.items);
      $('#page-info').textContent = `Стр. ${data.page} из ${data.pages} · ${data.total} записей`;
      $('#pagination').hidden = data.pages <= 1;
      $('#btn-prev').disabled = data.page <= 1;
      $('#btn-next').disabled = data.page >= data.pages;
    } catch (e) {
      $('#list-loading').hidden = true;
      $('#list-empty').hidden = false;
      toast(e.message || String(e), 'err');
    }
  }

  function openDrawer(item) {
    selected = item;
    $('#drawer-title').textContent = item.requested_name || 'Заявка';
    $('#drawer-review-note').value = item.review_note || '';
    const body = $('#drawer-body');
    body.innerHTML = `
      <div class="drawer-block">
        <label>СТО</label>
        <p>${escapeHtml(item.organization_name || '—')}</p>
      </div>
      <div class="drawer-block">
        <label>Запрошенное название</label>
        <p><strong>${escapeHtml(item.requested_name || '')}</strong></p>
      </div>
      ${
        item.category_hint
          ? `<div class="drawer-block"><label>Подсказка категории</label><p>${escapeHtml(item.category_hint)}</p></div>`
          : ''
      }
      ${
        item.note
          ? `<div class="drawer-block"><label>Комментарий от СТО</label><pre>${escapeHtml(item.note)}</pre></div>`
          : ''
      }
      <div class="drawer-block">
        <label>Создано</label>
        <p class="mono-date">${formatDate(item.created_at)}</p>
      </div>
      ${
        item.reviewed_at
          ? `<div class="drawer-block"><label>Отмечено рассмотренным</label><p class="mono-date">${formatDate(item.reviewed_at)}</p></div>`
          : ''
      }
    `;
    $('#drawer-backdrop').hidden = false;
    $('#drawer').hidden = false;
    $('#drawer').setAttribute('aria-hidden', 'false');
  }

  function closeDrawer() {
    selected = null;
    $('#drawer-backdrop').hidden = true;
    $('#drawer').hidden = true;
    $('#drawer').setAttribute('aria-hidden', 'true');
  }

  async function patchSelected(status) {
    if (!selected) return;
    const review_note = $('#drawer-review-note').value;
    try {
      await api('/internal/service-catalog/suggestions/' + selected.id, {
        method: 'PATCH',
        body: { status, review_note: review_note.trim() || null },
      });
      toast(status === 'reviewed' ? 'Сохранено как рассмотрено' : 'Возвращено в ожидание');
      closeDrawer();
      await Promise.all([loadStats(), loadList()]);
    } catch (e) {
      toast(e.message || String(e), 'err');
    }
  }

  async function tryBootstrap() {
    if (!token) {
      showView('login');
      return;
    }
    try {
      await loadMe();
      showView('app');
      await Promise.all([loadStats(), loadList()]);
    } catch {
      showView('login');
    }
  }

  $('#form-login').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const fd = new FormData(ev.target);
    const email = String(fd.get('email') || '').trim();
    const password = String(fd.get('password') || '');
    const errEl = $('#login-error');
    errEl.hidden = true;
    $('#btn-login').disabled = true;
    try {
      const res = await fetch(API + '/internal/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(data.message || 'Неверный email или пароль');
      }
      token = data.access_token;
      localStorage.setItem(TOKEN_KEY, token);
      await tryBootstrap();
    } catch (e) {
      errEl.textContent = e.message || String(e);
      errEl.hidden = false;
    } finally {
      $('#btn-login').disabled = false;
    }
  });

  $('#btn-logout').addEventListener('click', () => {
    token = '';
    localStorage.removeItem(TOKEN_KEY);
    showView('login');
  });

  $('#btn-refresh').addEventListener('click', async () => {
    try {
      await Promise.all([loadStats(), loadList()]);
      toast('Данные обновлены');
    } catch (e) {
      toast(e.message || String(e), 'err');
    }
  });

  $$('#filters .chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      $$('#filters .chip').forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');
      filterStatus = chip.dataset.status || 'all';
      page = 1;
      loadList();
    });
  });

  let searchTimer;
  $('#input-search').addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      searchQ = $('#input-search').value;
      page = 1;
      loadList();
    }, 320);
  });

  $('#btn-prev').addEventListener('click', () => {
    if (page > 1) {
      page--;
      loadList();
    }
  });
  $('#btn-next').addEventListener('click', () => {
    if (page < listMeta.pages) {
      page++;
      loadList();
    }
  });

  $('#drawer-close').addEventListener('click', closeDrawer);
  $('#drawer-backdrop').addEventListener('click', closeDrawer);
  $('#drawer-reviewed').addEventListener('click', () => patchSelected('reviewed'));
  $('#drawer-pending').addEventListener('click', () => patchSelected('pending'));

  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape' && !$('#drawer').hidden) closeDrawer();
  });

  tryBootstrap();
})();
