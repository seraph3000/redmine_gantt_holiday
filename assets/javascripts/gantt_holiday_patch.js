/* =====================================================================
 * Redmine Gantt Holiday plugin
 * gantt_holiday_patch.js
 *
 * Copyright (c) 2026 Seraph3000
 * https://github.com/seraph3000/redmine_gantt_holiday
 * ===================================================================== */

$(function() {
    var $ganttArea = $('#gantt_area');
    if (!$ganttArea.length) return;

    var $subjectsContainer = $('.gantt_subjects_container');
    var $rightAllHdrs = $ganttArea.children('.gantt_hdr');
    if (!$rightAllHdrs.length) return;

    var bgHdr = $rightAllHdrs[0];
    var headerHeight = bgHdr.offsetHeight;
    var contentWidth = parseInt(bgHdr.style.width) || $ganttArea[0].scrollWidth;

    // ========================================
    // 1. 休日・土曜カラー化（クローン前に実施）
    // ========================================
    var holidays = {};
    var workdays = {};

    // 祝日データがある場合のみ辞書を構築（無くてもこの後の土日色付けは走る）
    if (typeof gantt_holidays !== 'undefined' && gantt_holidays.length) {
        for (var i = 0; i < gantt_holidays.length; i++) {
            var item = gantt_holidays[i];
            if (typeof item === 'object' && item !== null) {
                if (item.active) {
                    holidays[item.date] = true;
                } else {
                    workdays[item.date] = true; // active:false なら稼働日
                }
            } else if (typeof item === 'string') {
                // 古いキャッシュ対策の安全装置
                holidays[item] = true;
            }
        }
    }

    // 土日・祝日のカラー化は無条件で実行
    if (typeof gantt_start_date !== 'undefined') {
        var startDate = new Date(gantt_start_date);
        var dayGroups = {};
        $rightAllHdrs.each(function() {
            var t = parseInt(this.style.top) || 0;
            if (t > 19 && this.offsetHeight > headerHeight) {
                if (!dayGroups[t]) dayGroups[t] = [];
                dayGroups[t].push({ el: this, left: parseInt(this.style.left) || 0 });
            }
        });

        Object.keys(dayGroups).forEach(function(topVal) {
            var cells = dayGroups[topVal];
            cells.sort(function(a, b) { return a.left - b.left; });
            for (var i = 0; i < cells.length; i++) {
                var d = new Date(startDate.getTime() + i * 86400000);
                var dateStr = d.toISOString().split('T')[0];
                var dow = d.getUTCDay();

                // 稼働日(チェックOFF)はスキップ
                if (workdays[dateStr]) continue;

                if (dow === 6) {
                    cells[i].el.classList.add('is-saturday');
                } else if (dow === 0 || holidays[dateStr]) {
                    cells[i].el.classList.add('is-holiday');
                }
            }
        });
    }

    // ========================================
    // 2. ヘッダー固定（オーバーレイ方式）最終形態
    // ========================================
    
    // 真のヘッダー領域の高さを、左側の背景要素から「確実」に取得する
    var totalHeaderHeight = 72; // 安全のためのフォールバック
    var $leftBg = $('.gantt_subjects_container').children('.gantt_hdr').first();
    if ($leftBg.length) {
        totalHeaderHeight = $leftBg[0].offsetHeight;
    }

    // 右側用オーバーレイ作成
    var overlay = document.createElement('div');
    overlay.style.cssText =
        'position:absolute;top:0;left:0;' +
        'width:' + contentWidth + 'px;' +
        'height:' + totalHeaderHeight + 'px;' +
        'overflow:hidden;z-index:150;display:none;';

    $rightAllHdrs.each(function() {
        var t = parseInt(this.style.top) || 0;
        
        // トップ位置がヘッダー領域内から始まる要素は「すべて」クローンする
        if (t < totalHeaderHeight) {
            var clone = this.cloneNode(true);
            
            // 日付テキストは「下まで貫く巨大グリッド」の先頭に書かれている！
            // そのため除外するのではなく、クローンした後に「ヘッダーの高さ」でスパッと切り落とす。
            if (this.offsetHeight > totalHeaderHeight) {
                clone.style.height = (totalHeaderHeight - t) + 'px';
                clone.style.overflow = 'hidden'; // これで下にはみ出たグリッドを消滅させる
            }
            overlay.appendChild(clone);
        }
    });

    $ganttArea[0].appendChild(overlay);

    // 左側のカラムヘッダー回収
    var leftHeadersData = [];
    $('.gantt_subjects_container, .gantt_selected_column_container').children('.gantt_hdr').each(function() {
        var t = parseInt(this.style.top) || 0;
        var h = this.offsetHeight;
        
        // 高さがヘッダー領域に収まる本物のヘッダーだけを一緒にスクロールさせる
        if (t < totalHeaderHeight && h <= totalHeaderHeight + 2) {
            $(this).css('background-color', '#eee');
            leftHeadersData.push({
                el: this,
                origTop: t
            });
        }
    });

    var areaEl = $ganttArea[0];
    var ticking = false;

    function syncHeaders() {
        var rect = areaEl.getBoundingClientRect();
        var offset = -rect.top;
        var maxOffset = areaEl.clientHeight - totalHeaderHeight;

        if (offset > 0 && offset < maxOffset) {
            overlay.style.top = offset + 'px';
            overlay.style.display = 'block';
            
            leftHeadersData.forEach(function(item) {
                item.el.style.top = (item.origTop + offset) + 'px';
                item.el.style.zIndex = '150';
            });
        } else {
            overlay.style.display = 'none';
            leftHeadersData.forEach(function(item) {
                item.el.style.top = item.origTop + 'px';
                item.el.style.zIndex = '';
            });
        }
        ticking = false;
    }

    window.addEventListener('scroll', function() {
        if (!ticking) {
            requestAnimationFrame(syncHeaders);
            ticking = true;
        }
    }, { passive: true });

    window.addEventListener('resize', function() {
        if (!ticking) {
            requestAnimationFrame(syncHeaders);
            ticking = true;
        }
    }, { passive: true });

  // ========================================
  // 3. マウスドラッグでの横スクロール (Grab to Scroll) 最終形態
  // ========================================
  var isDown = false;
  var startX;
  var scrollLeft;
  var areaEl = $ganttArea[0];

  // ドラッグ中だけ「画面内の全要素」のカーソルを強制的にグーにする必殺技
  var grabStyle = '<style id="drag-cursor"> * { cursor: grabbing !important; } </style>';

  $ganttArea.on('mousedown', function(e) {
    // 横スクロールバーがない（必要ない）場合は発動しない（矢印のまま）
    if (areaEl.scrollWidth <= areaEl.clientWidth + 1) return;
    // 左クリック以外は無視
    if (e.which !== 1) return;

    // Aタグ（チケットへのリンク等）を掴んだ時はクリック操作を優先する
    if ($(e.target).closest('a').length > 0) return;
      isDown = true;
      startX = e.pageX - areaEl.offsetLeft;
      scrollLeft = areaEl.scrollLeft;
      // 強制的に「グー」アイコンにする（Redmineの子要素のカーソル設定をねじ伏せる）
      $('head').append(grabStyle);
      // ブラウザ標準のテキスト選択やドラッグを無効化（これが無いと掴めない！）
      e.preventDefault();
  });

  $(document).on('mousemove', function(e) {
    if (!isDown) return;
      // 安全装置: 画面外で指を離して戻ってきた時に「グー」のまま固まるのを防ぐ
      if (e.buttons === 0) {
        isDown = false;
        $('#drag-cursor').remove();
          return;
      }

      e.preventDefault(); 
      var x = e.pageX - areaEl.offsetLeft;
      var walk = (x - startX); // 移動量
      areaEl.scrollLeft = scrollLeft - walk;
  });

  $(document).on('mouseup', function() {
    if (isDown) {
      isDown = false;
      // 確実にお行儀よく「矢印」に戻す
      $('#drag-cursor').remove();
    }
  });

});