# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin - 親子操作（子チケットを食べる）機能
#
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================
#
# 既存の GanttHolidayHooks（休日表示）とは責務を分離した独立フック。
# hook点も重複しない（向こうは view_layouts_base_html_head のみ）。
# =====================================================================

class OyakodonHooks < Redmine::Hook::ViewListener
  # ------------------------------------------------------------------
  # 1. コンテキストメニュー末尾に項目を追加
  #    - 単一チケット選択時のみ
  #    - 「子チケットを食べる」: 親候補として編集モード開始
  #    - 「ごちそうさま」      : 親を持つチケットのみ、その場で親から離す
  #    - サブメニューを作らずフラットな <a> 単発
  #      （ガントでは folder 型サブメニューが z-index 競合で
  #       意図せず閉じる不具合があるため／Redmine Defect #41925）
  # ------------------------------------------------------------------
  def view_issues_context_menu_end(context = {})
    issues = context[:issues]
    return '' if issues.blank? || issues.size != 1

    # この hook は一覧・ガント・カレンダー等あらゆる
    # コンテキストメニューで発火する（引数に画面種別が無い）。
    # oyakodon はガント専用なので、back URL がガント由来のときだけ出す。
    back = context[:back].to_s
    return '' unless back =~ %r{/issues/gantt\b} || back =~ %r{/gantt\b}

    issue = issues.first
    project = issue.project
    return '' unless project
    return '' unless project.module_enabled?(:gantt_holiday)
    return '' unless User.current.allowed_to?(:oyakodon_child_issue, project)

    # 親候補IDを data 属性で JS に渡すだけ。
    # クリック後の挙動（編集モード突入）はすべて JS 側。
    link = link_to(
      l(:label_oyakodon_child_issue),
      '#',
      class: 'js-oyakodon-start',
      data: { parent_id: issue.id, project_id: project.id }
    )
    html = content_tag(:li, link)

    # 親を持つチケットには「ごちそうさま」も並べる。
    # POST 送信は JS 側で完結。
    if issue.parent_id.present?
      release_link = link_to(
        l(:label_oyakodon_release),
        '#',
        class: 'js-oyakodon-release',
        data: { child_id: issue.id }
      )
      html += content_tag(:li, release_link)
    end
    html
  end

  # ------------------------------------------------------------------
  # 2. ガント画面の最下部に、編集モード用ポップアップの骨組みと
  #    JS/CSS を差し込む
  #    - ガント画面（controller_name == 'gantts'）限定
  #    - インライン JS は既存フックと同様 view_context 経由で
  #      nonce 対応（ViewListener は request context を持たないため
  #      content_security_policy_nonce を直接呼べない）
  # ------------------------------------------------------------------
  def view_layouts_base_body_bottom(context = {})
    controller = context[:controller]
    return '' unless controller&.controller_name == 'gantts'

    project = controller.instance_variable_get(:@project)
    return '' unless project
    return '' unless project.module_enabled?(:gantt_holiday)
    return '' unless User.current.allowed_to?(:oyakodon_child_issue, project)

    view = controller.view_context

    bulk_url =
      begin
        view.url_for(controller: 'oyakodon', action: 'bulk_assign', only_path: true)
      rescue => e
        Rails.logger.error("[oyakodon] bulk_assign route not found: #{e.message}")
        return ''
      end

      release_base =
      begin
        view.url_for(controller: 'oyakodon', action: 'release', id: '__ID__', only_path: true).sub('__ID__', '')
      rescue => e
        Rails.logger.error("[oyakodon] release route not found: #{e.message}")
        nil
      end

      # 確定送信先URLとラベルを JS に渡す（i18nはサーバ側で解決）
    config_json =  ERB::Util.json_escape({
      bulkAssignUrl: bulk_url,
      releaseUrlBase: release_base,
      labels: {
        title:    l(:label_oyakodon_popup_title),
        parent:   l(:label_oyakodon_parent),
        children: l(:label_oyakodon_children),
        confirm:  l(:label_oyakodon_confirm),
        cancel:   l(:button_cancel),
        empty:    l(:label_oyakodon_no_children),
        releaseConfirm: l(:confirm_oyakodon_release),
        releaseFailed:  l(:error_oyakodon_release_failed)
      }
    }.to_json)

    inline_js = view.javascript_tag(
      "var oyakodon_config = #{config_json};",
      nonce: true
    )

    popup = content_tag(:div, id: 'oyakodon-popup', class: 'oyakodon-hidden') do
      header = content_tag(:div, class: 'oyakodon-header') do
        content_tag(:span, l(:label_oyakodon_popup_title), class: 'oyakodon-title') +
          content_tag(:span, '×', class: 'oyakodon-close', title: l(:button_cancel))
      end

      body = content_tag(:div, class: 'oyakodon-body') do
        content_tag(:div, '', class: 'oyakodon-parent') +
          content_tag(:ul, '', class: 'oyakodon-children')
      end

      footer = content_tag(:div, class: 'oyakodon-footer') do
        content_tag(:button, l(:label_oyakodon_confirm), type: 'button', class: 'oyakodon-confirm') +
          content_tag(:button, l(:button_cancel), type: 'button', class: 'oyakodon-cancel')
      end

      header + body + footer
    end

    tags = [
      stylesheet_link_tag('oyakodon', plugin: 'redmine_gantt_holiday'),
      inline_js,
      popup,
      javascript_include_tag('oyakodon', plugin: 'redmine_gantt_holiday')
    ]
    tags.join("\n").html_safe
  end
end