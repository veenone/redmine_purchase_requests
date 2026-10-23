module RedminePurchaseRequests
  # Shared TPC code filtering.
  #
  # Used by controllers whose records reference a TPC code, and by those
  # listing TpcCode itself -- the latter pass column: :id, since for them the
  # filter selects rows rather than following an association.
  #
  # params[:tpc_code_id] is accepted both as a scalar ("?tpc_code_id=5") and as
  # an array ("?tpc_code_id[]=5&tpc_code_id[]=7"), so links and bookmarks made
  # before multi-select continue to resolve correctly.
  module TpcFilterable
    extend ActiveSupport::Concern

    included do
      helper_method(:selected_tpc_code_ids, :tpc_filter_active?, :tpc_selected?) if respond_to?(:helper_method)
    end

    # Selected ids as an array of non-blank strings. Empty when no filter set.
    def selected_tpc_code_ids
      @selected_tpc_code_ids ||=
        Array(params[:tpc_code_id]).reject(&:blank?).map(&:to_s)
    end

    # Prefer this over truthiness checks: an empty array is truthy in Ruby, so
    # `if selected_tpc_code_ids` would wrongly report an active filter.
    def tpc_filter_active?
      selected_tpc_code_ids.any?
    end

    # Every id sharing a TPC number with one of the selected ids, within the
    # scope this page can see.
    #
    # The filter presents a global code and its project-scoped namesake as one
    # entry, submitting only the representative id. Records link to one
    # specific row, so matching on the submitted id alone would silently drop
    # everything hanging off the sibling.
    def expanded_tpc_code_ids
      @expanded_tpc_code_ids ||=
        if tpc_filter_active?
          numbers = TpcCode.where(id: selected_tpc_code_ids)
                           .pluck(:tpc_number)
                           .map { |number| TpcCode.normalize_number(number) }
                           .uniq

          if numbers.any?
            siblings = tpc_sibling_scope
                       .where('LOWER(TRIM(tpc_codes.tpc_number)) IN (?)', numbers)
                       .pluck(:id)
                       .map(&:to_s)
            selected_tpc_code_ids | siblings
          else
            # Ids matching no row: passed through untouched, so the filter
            # still returns nothing rather than quietly becoming unfiltered.
            selected_tpc_code_ids
          end
        else
          []
        end
    end

    # Expansion stays inside what the current page can see -- global codes
    # plus this project's. Unbounded, filtering inside one project could pull
    # in a same-numbered code belonging to another.
    def tpc_sibling_scope
      project = instance_variable_defined?(:@project) ? @project : nil
      project ? TpcCode.available_for_project(project) : TpcCode
    end

    # Narrows scope to the selected TPC codes, or returns it untouched when no
    # filter is set. Pass column: :id when scope is TpcCode itself.
    def apply_tpc_filter(scope, column: :tpc_code_id)
      return scope unless tpc_filter_active?

      scope.where(column => expanded_tpc_code_ids)
    end

    # Whether a given TPC id survives the current filter. Returns true when no
    # filter is set, so it can guard in-memory collections without a caller
    # having to special-case the unfiltered path.
    def tpc_selected?(tpc_id)
      return true unless tpc_filter_active?

      expanded_tpc_code_ids.include?(tpc_id.to_s)
    end
  end
end
