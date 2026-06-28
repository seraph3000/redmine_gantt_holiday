// =====================================================================
// Redmine Gantt Holiday plugin - 親子操作（子チケットを食べる / oyakodon）
//
// Copyright (c) 2026 Seraph3000
// https://github.com/seraph3000/redmine_gantt_holiday
// =====================================================================
//
// ガント画面の編集モード。親を右クリック→「子チケットを食べる」で起動。
// ガント行(a.issue)を左クリックすると子(具)として集め、確定で
// oyakodon#bulk_assign に投げて parent_issue_id を一括更新する。
//
// 設計方針:
//  - 全面オーバーレイは敷かない。下のガント行クリック/スクロールを
//    生かすため、編集モード中だけ a.issue のクリックを横取りする。
//  - クリック横取りは capture フェーズで preventDefault。
//    （ガントのチケット名は素の <a href> なので確実に止まる）
//  - 別プロジェクト・自己参照はクリック段階で弾く（サーバ側でも再検証）。
// =====================================================================

(function () {
  'use strict';

  // 編集モードの状態
  var state = {
    active: false,
    parentId: null,
    projectId: null,
    children: []   // [{id: Number, el: HTMLElement}]
  };

  var cfg = window.oyakodon_config || {};
  var L = cfg.labels || {};

  // ------------------------------------------------------------------
  // ガント行(a.issue)から issue ID を取り出す
  //   href が /issues/123 形式なので末尾の数字を拾う
  // ------------------------------------------------------------------
  function issueIdFromAnchor(a) {
    if (!a) { return null; }
    var href = a.getAttribute('href') || '';
    var m = href.match(/\/issues\/(\d+)/);
    return m ? parseInt(m[1], 10) : null;
  }

  // クリックされた要素から、最も近い a.issue を辿る
  function closestIssueAnchor(target) {
    var el = target;
    while (el && el !== document) {
      if (el.tagName === 'A' && el.classList.contains('issue')) { return el; }
      el = el.parentNode;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 編集モード開始（コンテキストメニューの項目クリックから呼ばれる）
  // ------------------------------------------------------------------
  function startOyakodon(parentId, projectId) {
    state.active = true;
    state.parentId = parentId;
    state.projectId = projectId;
    state.children = [];

    renderParent();
    renderChildren();
    showPopup();
    document.body.classList.add('oyakodon-mode');
  }

  function endOyakodon() {
    // 具のハイライトを全解除
    state.children.forEach(function (c) {
      if (c.el) { c.el.classList.remove('oyakodon-selected'); }
    });
    state.active = false;
    state.parentId = null;
    state.projectId = null;
    state.children = [];
    hidePopup();
    document.body.classList.remove('oyakodon-mode');
  }

  // ------------------------------------------------------------------
  // ガント行クリックの横取り（capture フェーズ）
  //   編集モード中のみ作動。a.issue の詳細遷移を殺して具に追加。
  //   .expander（ツリー開閉）は対象外＝開閉でスクロール探索できる。
  // ------------------------------------------------------------------
  function onGanttClickCapture(e) {
    if (!state.active) { return; }

    // 開閉アイコンは素通し（子を探すために開閉したいので殺さない）
    if (e.target.closest && e.target.closest('.expander')) { return; }

    var anchor = closestIssueAnchor(e.target);
    if (!anchor) { return; }

    // ガントの subject 領域内のリンクのみ対象
    if (!anchor.closest('.gantt_subjects')) { return; }

    // ここから先は「具に追加」操作。詳細遷移を確実に止める。
    e.preventDefault();
    e.stopPropagation();

    var id = issueIdFromAnchor(anchor);
    if (!id) { return; }

    toggleChild(id, anchor);
  }

  // 編集モード中の右クリック抑止（標準コンテキストメニューを出さない）
  function onGanttContextMenuCapture(e) {
    if (!state.active) { return; }
    if (!e.target.closest || !e.target.closest('.gantt_subjects')) { return; }
    e.preventDefault();
    e.stopPropagation();
  }

  // ------------------------------------------------------------------
  // 具のトグル（追加 / 解除）
  // ------------------------------------------------------------------
  function toggleChild(id, anchor) {
    // 親自身は具にできない（自己参照）
    if (id === state.parentId) {
      // labels.cannotSelf が未定義でも無音にならないようフォールバック
      flashPopup(L.cannotSelf || '親チケット自身は子にできません');
      return;
    }

    var idx = indexOfChild(id);
    if (idx >= 0) {
      // 既に具 → 解除
      var removed = state.children.splice(idx, 1)[0];
      if (removed.el) { removed.el.classList.remove('oyakodon-selected'); }
    } else {
      // 単一プロジェクトのガントでは全行が同プロジェクト。
      // global gantt で別プロジェクト行が混じるケースはサーバ側
      // （child.project_id != parent.project_id）で最終的に弾く。
      state.children.push({ id: id, el: anchor });
      anchor.classList.add('oyakodon-selected');
    }
    renderChildren();
  }

  function indexOfChild(id) {
    for (var i = 0; i < state.children.length; i++) {
      if (state.children[i].id === id) { return i; }
    }
    return -1;
  }

  // ------------------------------------------------------------------
  // ポップアップ描画
  // ------------------------------------------------------------------
  function renderParent() {
    var box = document.querySelector('#oyakodon-popup .oyakodon-parent');
    if (box) {
      box.textContent = (L.parent || 'Parent') + ': #' + state.parentId;
    }
  }

  function renderChildren() {
    var ul = document.querySelector('#oyakodon-popup .oyakodon-children');
    if (!ul) { return; }
    ul.innerHTML = '';

    if (state.children.length === 0) {
      var li = document.createElement('li');
      li.className = 'oyakodon-empty';
      li.textContent = L.empty || '';
      ul.appendChild(li);
      return;
    }

    // No.（チケット番号）のみ表示。件名は出さない。
    state.children.forEach(function (c) {
      var li = document.createElement('li');
      var no = document.createElement('span');
      no.className = 'oyakodon-no';
      no.textContent = '#' + c.id;

      var del = document.createElement('span');
      del.className = 'oyakodon-remove';
      del.textContent = '×';
      del.addEventListener('click', function () {
        toggleChild(c.id, c.el); // 再トグル＝解除
      });

      li.appendChild(no);
      li.appendChild(del);
      ul.appendChild(li);
    });
  }

  // ------------------------------------------------------------------
  // ポップアップ表示制御＋ドラッグ移動
  // ------------------------------------------------------------------
  function showPopup() {
    var p = document.getElementById('oyakodon-popup');
    if (p) { p.classList.remove('oyakodon-hidden'); }
  }

  function hidePopup() {
    var p = document.getElementById('oyakodon-popup');
    if (p) { p.classList.add('oyakodon-hidden'); }
  }

  function flashPopup(msg) {
    if (!msg) { return; }
    var p = document.getElementById('oyakodon-popup');
    if (!p) { return; }
    p.classList.add('oyakodon-flash');
    setTimeout(function () { p.classList.remove('oyakodon-flash'); }, 300);
  }

  function setupDrag() {
    var popup = document.getElementById('oyakodon-popup');
    if (!popup) { return; }
    var header = popup.querySelector('.oyakodon-header');
    if (!header) { return; }

    var dragging = false;
    var offsetX = 0;
    var offsetY = 0;

    header.addEventListener('mousedown', function (e) {
      // 閉じるボタン上では掴ませない
      if (e.target.classList.contains('oyakodon-close')) { return; }
      dragging = true;
      var rect = popup.getBoundingClientRect();
      offsetX = e.clientX - rect.left;
      offsetY = e.clientY - rect.top;
      e.preventDefault();
    });

    document.addEventListener('mousemove', function (e) {
      if (!dragging) { return; }
      popup.style.left = (e.clientX - offsetX) + 'px';
      popup.style.top = (e.clientY - offsetY) + 'px';
      popup.style.right = 'auto';   // 初期の固定位置(right)指定を解除
      popup.style.bottom = 'auto';
    });

    document.addEventListener('mouseup', function () {
      dragging = false;
    });
  }

  // ------------------------------------------------------------------
  // 確定（いただきます）→ bulk_assign へ POST
  // ------------------------------------------------------------------
  function confirmOyakodon() {
    if (!state.active) { return; }
    if (state.children.length === 0) {
      flashPopup(L.empty || '');
      return;
    }

    var childIds = state.children.map(function (c) { return c.id; });
    var token = document.querySelector('meta[name="csrf-token"]');
    var csrf = token ? token.getAttribute('content') : '';

    var confirmBtn = document.querySelector('#oyakodon-popup .oyakodon-confirm');
    if (confirmBtn) { confirmBtn.disabled = true; }

    fetch(cfg.bulkAssignUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf,
        'Accept': 'application/json'
      },
      credentials: 'same-origin',
      body: JSON.stringify({
        parent_id: state.parentId,
        child_ids: childIds
      })
    })
      .then(function (res) { return res.json().then(function (j) { return { status: res.status, body: j }; }); })
      .then(function (r) {
        var b = r.body || {};
        if (r.status >= 200 && r.status < 300 && (b.ng === 0)) {
          // 全件成功 → ガント再読み込みで構造を反映
          endOyakodon();
          window.location.reload();
        } else {
          // 一部失敗 or エラー → 結果を出して籠は維持
          if (confirmBtn) { confirmBtn.disabled = false; }
          var msg = (b.errors && b.errors.length) ? b.errors.join('\n') : 'Error';
          alert(msg);   // 簡易表示。必要ならポップアップ内 DOM へ
          // 成功分があれば反映のためリロードする選択肢もあるが、
          // 「失敗分は籠に残す」方針なのでここでは維持する。
        }
      })
      .catch(function () {
        if (confirmBtn) { confirmBtn.disabled = false; }
        alert('Network error');
      });
  }

  // ------------------------------------------------------------------
  // ごちそうさま → /oyakodon/release/:id へ POST
  //   - 籠UIは経由しない（ガント上で親子関係が見えている前提）
  //   - 子の配下にぶら下がっている孫以下は子に追従（Redmine 標準仕様）
  // ------------------------------------------------------------------
  function releaseChild(childId) {
    // releaseUrlBase はサーバ側(hook)が url_for で生成して渡す。
    // 渡ってない場合はサブURI運用で誤URLを叩く事故になるため実行しない。
    if (!cfg.releaseUrlBase) {
      window.alert(L.releaseFailed || 'ごちそうさまに失敗しました');
      return;
    }

    var msg = L.releaseConfirm || 'このチケットを親から離します。よろしいですか？';
    if (!window.confirm(msg)) { return; }

    var url = cfg.releaseUrlBase + childId;

    var tokenMeta = document.querySelector('meta[name="csrf-token"]');
    var csrf = tokenMeta ? tokenMeta.getAttribute('content') : '';

    fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf,
        'Accept': 'application/json'
      },
      credentials: 'same-origin',
      body: JSON.stringify({ id: childId })
    })
    .then(function (r) {
      return r.json().then(function (j) { return { status: r.status, body: j }; });
    })
    .then(function (res) {
      if (res.body && res.body.ok === 1) {
        location.reload();
      } else {
        var errs = (res.body && res.body.errors) || ['unknown error'];
        window.alert(errs.join('\n'));
      }
    })
    .catch(function () {
      window.alert(L.releaseFailed || 'ごちそうさまに失敗しました');
    });
  }

  // ------------------------------------------------------------------
  // 初期化
  // ------------------------------------------------------------------
  function init() {
    // メニュー項目「子チケットを食べる」クリック → 編集モード開始
    document.addEventListener('click', function (e) {
      var starter = e.target.closest && e.target.closest('.js-oyakodon-start');
      if (!starter) { return; }
      e.preventDefault();
      var pid = parseInt(starter.getAttribute('data-parent-id'), 10);
      var prj = parseInt(starter.getAttribute('data-project-id'), 10);
      if (pid) { startOyakodon(pid, prj); }
    });

    // 【追記】メニュー項目「ごちそうさま」クリック → その場で親から離す
    document.addEventListener('click', function (e) {
      var releaser = e.target.closest && e.target.closest('.js-oyakodon-release');
      if (!releaser) { return; }
      e.preventDefault();
      var cid = parseInt(releaser.getAttribute('data-child-id'), 10);
      if (cid) { releaseChild(cid); }
    });

    // ガント行クリック横取り（capture フェーズで標準遷移より先に拾う）
    document.addEventListener('click', onGanttClickCapture, true);
    document.addEventListener('contextmenu', onGanttContextMenuCapture, true);

    // ポップアップのボタン
    var confirmBtn = document.querySelector('#oyakodon-popup .oyakodon-confirm');
    var cancelBtn = document.querySelector('#oyakodon-popup .oyakodon-cancel');
    var closeBtn = document.querySelector('#oyakodon-popup .oyakodon-close');
    if (confirmBtn) { confirmBtn.addEventListener('click', confirmOyakodon); }
    if (cancelBtn) { cancelBtn.addEventListener('click', endOyakodon); }
    if (closeBtn) { closeBtn.addEventListener('click', endOyakodon); }

    setupDrag();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();