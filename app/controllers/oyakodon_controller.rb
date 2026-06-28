# frozen_string_literal: true

# =====================================================================
# Redmine Gantt Holiday plugin - 親子操作（子チケットを食べる / oyakodon）
#
# Copyright (c) 2026 Seraph3000
# https://github.com/seraph3000/redmine_gantt_holiday
# =====================================================================
#
# ガント画面の編集モードで集めた子チケット群を、指定した親チケットの
# 子として一括設定する。parent_issue_id の更新のみを行い、循環参照
# チェックは Redmine 本体の Issue バリデーションに委譲する。
#
# release: 子チケットを親から離す（俗称: ごちそうさま）。子の配下に
# ぶら下がっている孫以下はそのまま子に追従する（Redmine 標準仕様）。
# =====================================================================

class OyakodonController < ApplicationController
  before_action :find_parent_issue,  only: [:bulk_assign]
  before_action :find_child_issue,   only: [:release]
  before_action :authorize_oyakodon

  # 1回の確定で扱う子の上限（タイムアウト・誤操作対策）
  MAX_CHILDREN = 200

  def bulk_assign
    child_ids = Array(params[:child_ids]).map(&:to_i).reject(&:zero?).uniq

    if child_ids.empty?
      return render json: { ok: 0, ng: 0, errors: [l(:label_oyakodon_no_children)] },
                    status: :unprocessable_entity
    end

    if child_ids.size > MAX_CHILDREN
      return render json: { ok: 0, ng: 0, errors: [l(:error_oyakodon_too_many, count: MAX_CHILDREN)] },
                    status: :unprocessable_entity
    end

    ok = 0
    ng = 0
    errors = []

    # 可視かつ編集可能なものだけを対象にする。
    children = Issue.where(id: child_ids).to_a
    found_ids = children.map(&:id)

    # リクエストにあったが取得できなかったID（不可視・存在しない）を記録
    (child_ids - found_ids).each do |missing|
      ng += 1
      errors << l(:error_oyakodon_not_found, id: missing)
    end

    children.each do |child|
      # 別プロジェクトのチケットは弾く。
      # 親に付けると子が親のプロジェクトへ移動し、元プロジェクトから
      # 消えてしまうため（混乱の元）。同一プロジェクト内のみ許可。
      if child.project_id != @parent_issue.project_id
        ng += 1
        errors << l(:error_oyakodon_cross_project, id: child.id)
        next
      end

      # 自己参照（親自身を子にする）は明確に弾く
      if child.id == @parent_issue.id
        ng += 1
        errors << l(:error_oyakodon_self_reference, id: child.id)
        next
      end

      # 編集権限のないチケットは弾く
      unless child.editable?
        ng += 1
        errors << l(:error_oyakodon_not_editable, id: child.id)
        next
      end

      child.init_journal(User.current)
      child.parent_issue_id = @parent_issue.id

      # save で本体バリデーションが走る。循環参照はここで弾かれる。
      if child.save
        ok += 1
      else
        ng += 1
        errors << "##{child.id}: #{child.errors.full_messages.join(', ')}"
      end
    end

    render json: {
      ok: ok,
      ng: ng,
      parent_id: @parent_issue.id,
      errors: errors
    }
  end


  # ------------------------------------------------------------------
  # ごちそうさま: 子チケットを親から離す
  #   - parent_issue_id = nil で実装
  #   - 子の配下にぶら下がっている孫以下は子に追従（Redmine 標準仕様）
  #   - 循環参照やバリデーションは Redmine 本体に委譲
  # ------------------------------------------------------------------
  def release
    if @child_issue.parent_id.nil?
      return render json: { ok: 0, ng: 0, errors: [l(:error_oyakodon_no_parent)] }
    end

    @child_issue.init_journal(User.current)
    @child_issue.parent_issue_id = nil

    if @child_issue.save
      render json: { ok: 1, ng: 0, errors: [], id: @child_issue.id }
    else
      render json: { ok: 0, ng: 1, errors: @child_issue.errors.full_messages }
    end
  end

  private

  def find_parent_issue
    @parent_issue = Issue.find(params[:parent_id])
    @project = @parent_issue.project
  rescue ActiveRecord::RecordNotFound
    render json: { ok: 0, ng: 0, errors: [l(:error_oyakodon_parent_not_found)] },
           status: :not_found
  end

  def find_child_issue
    @child_issue = Issue.find(params[:id])
    @project = @child_issue.project
  rescue ActiveRecord::RecordNotFound
    render json: { ok: 0, ng: 0, errors: [l(:error_oyakodon_not_found, id: params[:id])] },
           status: :not_found
  end

  # 親チケットまたは子チケットのプロジェクトに対して
  # oyakodon_child_issue 権限を要求。
  # @project は find_parent_issue / find_child_issue で設定済み。
  def authorize_oyakodon
    return unless @project
    unless User.current.allowed_to?(:oyakodon_child_issue, @project)
      render json: { ok: 0, ng: 0, errors: [l(:error_oyakodon_forbidden)] },
             status: :forbidden
    end
  end
end
