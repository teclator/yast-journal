require 'yast'
require 'systemd_journal/time_helpers'
require 'systemd_journal/query_presenter'

Yast.import "UI"
Yast.import "Label"

module SystemdJournal
  # Dialog allowing the user to set the query used to display the journal
  # entries in SystemdJournal::EntriesDialog
  #
  # @see SystemdJournal::EntriesDialog
  class QueryDialog

    include Yast::UIShortcuts
    include Yast::I18n
    include TimeHelpers

    INPUT_WIDTH = 20

    def initialize(query)
      @query = query
    end

    # Displays the dialog and returns user's selection of query options.
    #
    # @return [DialogFilter] nil if user cancelled
    def run
      return nil unless create_dialog

      begin
        case Yast::UI.UserInput
        when :cancel
          nil
        when :ok
          query_from_widgets
        else
          raise "Unexpected input #{input}"
        end
      ensure
          Yast::UI.CloseDialog
      end
    end

  private

    # Translates the value of the widgets to a new DialogFilter object
    def query_from_widgets
      interval = Yast::UI.QueryWidget(Id(:interval), :CurrentButton)
      if interval == "Hash"
        interval = {
          since: time_from_widgets_for(:since), 
          until: time_from_widgets_for(:until)
        }
      end

      filters = {}
      QueryPresenter.filters.each do |filter|
        name = filter[:name]
        # If the checkbox is checked
        if Yast::UI.QueryWidget(Id(name), :Value)
          # Read the widget...
          value = widget_to_filter(name, filter[:multiple])
          # ...discarding empty values
          filters[name] = value unless value.empty?
        end
      end

      QueryPresenter.new(interval: interval, filters: filters)
    end

    # Draws the dialog
    def create_dialog
      Yast::UI.OpenDialog(
        VBox(
          # Header
          Heading(_("Entries to display")),
          # Interval
          Frame(
            _("Time interval"),
            interval_widget
          ),
          VSpacing(0.3),
          # Filters
          Frame(
            _("Filters"),
            filters_widget
          ),
          VSpacing(0.3),
          # Footer buttons
          HBox(
            PushButton(Id(:cancel), Yast::Label.CancelButton),
            PushButton(Id(:ok), Yast::Label.OKButton)
          )
        )
      )
    end

    def interval_widget
      RadioButtonGroup(Id(:interval), VBox(*interval_buttons))
    end

    # Array of radio buttons to select the interval
    def interval_buttons
      QueryPresenter.intervals.map do |int|
        selected = int[:value] === @query.interval
        value = int[:value].to_s
        widgets = [RadioButton(Id(value), int[:label], selected)]
        if value == "Hash"
          widgets << HSpacing(1)
          widgets.concat(dates_widgets)
        end
          
        Left(HBox(*widgets))
      end
    end

    # Array of widgets for selecting date/time thresholds
    def dates_widgets
      [
        *time_widgets_for(:since, since_value),
        Label("-"),
        *time_widgets_for(:until, until_value)
      ]
    end

    # Initial value for the :since widget, defaults to 24 hours ago
    def since_value
      if @query.interval.is_a?(Hash)
        @query.interval[:since]
      else
        Time.now - 24*60*60
      end
    end

    # Initial value for the :until widget, defaults to the current time
    def until_value
      if @query.interval.is_a?(Hash)
        @query.interval[:until]
      else
        Time.now
      end
    end

    # Widget allowing to set the filters
    def filters_widget
      filters = QueryPresenter.filters.map do |filter|
        name = filter[:name]
        Left(
          HBox(
            CheckBox(Id(name), filter[:label], !@query.filters[name].nil?),
            HSpacing(1),
            widget_for_filter(name, filter[:values])
          )
        )
      end
      VBox(*filters)
    end

    # Widget to set the value of a given filter.
    #
    # If the second argument is nil, an input field will be used. Otherwise, a
    # combo box will be returned.
    #
    # @param name [Symbol] name of the filter
    # @param values [Array] optional list of values for the combo box
    def widget_for_filter(name, values = nil)
      id = Id(:"#{name}_value")
      if values
        items = values.map do |value|
          Item(Id(value), value, @query.filters[name] == value)
        end
        ComboBox(id, "", items)
      else
        MinWidth(INPUT_WIDTH, InputField(id, "", filter_to_string(name)))
      end
    end

    # String representing the value of a filter.
    #
    # Used to fill the corresponding input field. If the filter has multiple
    # values, they will be concatenated with a whitespace as separator.
    def filter_to_string(name)
      value = @query.filters[name]
      if value.nil?
        ""
      elsif value.is_a?(Array)
        value.join(" ")
      else
        value
      end
    end

    # Reads the widget associated to a filter and returns its value, as
    # a String or an Array of strings.
    #
    # @param name [Symbol] name of the filter
    # @param multiple [Boolean] if true, an array will be returned
    def widget_to_filter(name, multiple)
      value = Yast::UI.QueryWidget(Id(:"#{name}_value"), :Value)
      if multiple
        value.split(" ")
      else
        value
      end
    end
  end
end

