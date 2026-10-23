module RedminePurchaseRequests
  # Plugin tables page at 10 rows by default.
  #
  # Redmine's per_page_option reads the global "objects per page" setting
  # (50 and up on this install), which is tuned for issue lists. The plugin
  # keeps its own sizes and remembers the reader's choice under its own
  # session key, so picking 10 here never shrinks the core issue list.
  module Paginatable
    extend ActiveSupport::Concern

    PER_PAGE_OPTIONS = [10, 25, 50, 100].freeze

    included do
      helper Helper
    end

    # Overrides ApplicationController#per_page_option, which Redmine's own
    # paginate/paginator call, so both pick up the plugin default.
    def per_page_option
      per_page = params[:per_page].to_i
      if PER_PAGE_OPTIONS.include?(per_page)
        session[:pr_per_page] = per_page
      else
        session[:pr_per_page] || PER_PAGE_OPTIONS.first
      end
    end

    # Redmine's paginate for rows already loaded into Ruby (dashboard rows
    # sorted in memory). Same [paginator, rows] return shape.
    def paginate_array(rows)
      pages = paginator(rows.size)
      [pages, rows.slice(pages.offset, pages.per_page) || []]
    end

    module Helper
      # Overrides Redmine::Pagination::Helper#per_page_options, which builds
      # the "Per page:" links under the pager, to offer the plugin's sizes.
      def per_page_options(_selected = nil, item_count = nil)
        max = PER_PAGE_OPTIONS.detect { |n| n >= item_count.to_i } || PER_PAGE_OPTIONS.last
        options = PER_PAGE_OPTIONS.select { |n| n <= max }
        options.size > 1 ? options : []
      end
    end
  end
end
