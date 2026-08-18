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

    # Narrows scope to the selected TPC codes, or returns it untouched when no
    # filter is set. Pass column: :id when scope is TpcCode itself.
    def apply_tpc_filter(scope, column: :tpc_code_id)
      return scope unless tpc_filter_active?

      scope.where(column => selected_tpc_code_ids)
    end

    # Whether a given TPC id survives the current filter. Returns true when no
    # filter is set, so it can guard in-memory collections without a caller
    # having to special-case the unfiltered path.
    def tpc_selected?(tpc_id)
      return true unless tpc_filter_active?

      selected_tpc_code_ids.include?(tpc_id.to_s)
    end
  end
end
