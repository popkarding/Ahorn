module Form

using Gtk, Gtk.ShortNames, Gtk.GConstants
using ..Ahorn

abstract type Option

end

struct Section
    name::String
    dataName::String

    options::Array{Option, 1}
    fieldOrder::Array{String, 1}

    function Section(name::String, options::Array{Option, 1}=Option[]; dataName::String=name, fieldOrder::Array{String, 1}=String[])
        return new(name, dataName, options, fieldOrder)
    end
end

# ListOption Helpers

function columnEditCallback(store::GtkListStore, col::Integer, row::Integer, value::Any)
    if typeof(store[row, col]) <: Number
        if Ahorn.isNumber(value)
            store[row, col] = Ahorn.parseNumber(value)
        end

    else
        store[row, col] = string(value)
    end
end

function setListButtonSensitivity(option::Option)
    rows, cols = Base.size(option.container.store)

    GAccessor.sensitive(option.addButton, rows < option.maxRows || option.maxRows == -1)
    GAccessor.sensitive(option.removeButton, rows > option.minRows)
end

function addListRow(option::Option)
    rows, cols = Base.size(option.container.store)

    if rows < option.maxRows || option.maxRows == -1
        push!(option.container.store, tuple([typ == String ? "0" : zero(typ) for typ in option.container.dataType.parameters]...))
        Ahorn.selectRow!(option.container, rows + 1)

        setListButtonSensitivity(option)
    end
end

function deleteListRow(option::Option)
    rows, cols = Base.size(option.container.store)

    if hasselection(option.container.selection)
        if rows > option.minRows || option.minRows == -1
            row = selected(option.container.selection)
            deleteat!(option.container.store, row)

            setListButtonSensitivity(option)
        end
    end
end


# Entry Constructors and functions

struct TextEntryOption <: Option
    name::String
    dataName::String

    label::Gtk.GtkLabel
    entry::Gtk.GtkEntry

    as::Type

    function TextEntryOption(name::String; dataName::String=name, tooltip::String="", value::String="", as::Type=String)
        label = Label(name, xalign=0.0, margin_start=8, tooltip_text=tooltip)
        entry = Entry(text=string(value))

        return new(name, dataName, label, entry, as)
    end
end

Base.size(option::TextEntryOption) = (2, 1)
getValue(option::TextEntryOption) = Ahorn.getEntryText(option.entry, option.as)
setValue!(option::TextEntryOption, value::Any) = Ahorn.setEntryText!(option.entry, string(value))
getGroup(option::TextEntryOption) = 0
setGtkProperty!(option::TextEntryOption, field::Symbol, value::Any) = set_gtk_property!(option.entry, field, value)
getGtkProperty(option::TextEntryOption, field::Symbol, typ::DataType) = get_gtk_property(option.entry, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::TextEntryOption, col::Integer=0, row::Integer=0)
    grid[col, row] = option.label
    grid[col + 1, row] = option.entry
end


struct TextViewOption <: Option
    name::String
    dataName::String

    textView::Gtk.GtkTextView
    scrollable::Gtk.GtkScrolledWindow

    function TextViewOption(name::String; dataName::String=name, tooltip::String="", value::String="", monospace::Bool=true, vexpand::Bool=true, hexpand::Bool=true)
        textView = TextView(
            vexpand=vexpand,
            hexpand=hexpand,
            monospace=monospace,
            tooltip_text=tooltip
        )

        Ahorn.setTextViewText!(textView, value)
        
        scrollable = ScrolledWindow(vexpand=vexpand, hexpand=hexpand)
        push!(scrollable, textView)

        return new(name, dataName, textView, scrollable)
    end
end

Base.size(option::TextViewOption) = (4, 2)
getValue(option::TextViewOption) = Ahorn.getTextViewText(option.textView)
setValue!(option::TextViewOption, value::String) = Ahorn.setTextViewText!(option.textView, value)
getGroup(option::TextViewOption) = 4
setGtkProperty!(option::TextViewOption, field::Symbol, value::Any) = set_gtk_property!(option.textView, field, value)
getGtkProperty(option::TextViewOption, field::Symbol, typ::DataType) = set_gtk_property!(option.textView, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::TextViewOption, col::Integer=0, row::Integer=0)
    grid[col:col + 3, row:row + 1] = option.scrollable
end


mutable struct TextChoiceOption <: Option
    name::String
    dataName::String

    label::Gtk.GtkLabel
    combobox::Gtk.GtkComboBoxText

    value::String
    choices::Array{String, 1}

    as::Type

    function TextChoiceOption(name::String, options::Array{T, 1}; dataName::String=name, tooltip::String="", value::H="", editable::Bool=false) where {T, H}
        label = Label(name, xalign=0.0, margin_start=8, tooltip_text=tooltip)
        combobox = ComboBoxText(editable)

        append!(combobox, string.(options))

        Ahorn.setComboIndex!(combobox, options, value)

        return new(name, dataName, label, combobox, string(value), string.(options), typeof(value))
    end
end

Base.size(option::TextChoiceOption) = (2, 1)
getValue(option::TextChoiceOption) = Ahorn.convertString(option.value, option.as)
setValue!(option::TextChoiceOption, value::Any) = Ahorn.setComboIndex!(option.combobox, option.choices, string(value))
getGroup(option::TextChoiceOption) = 1
setGtkProperty!(option::TextChoiceOption, field::Symbol, value::Any) = set_gtk_property!(option.combobox, field, value)
getGtkProperty(option::TextChoiceOption, field::Symbol, typ::DataType) = set_gtk_property!(option.combobox, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::TextChoiceOption, col::Integer=0, row::Integer=0)
    grid[col, row] = option.label
    grid[col + 1, row] = option.combobox

    @guarded signal_connect(option.combobox, "changed") do args...
        option.value = Gtk.GLib.@sigatom Gtk.bytestring(GAccessor.active_text(option.combobox))
    end
end


mutable struct DictionaryChoiceOption <: Option
    name::String
    dataName::String

    options::Dict{String, Any}

    label::Gtk.GtkLabel
    combobox::Gtk.GtkComboBoxText

    value::Any

    function DictionaryChoiceOption(name::String, options::Dict{String, T}; dataName::String=name, tooltip::String="", value::H=nothing) where {T, H}
        label = Label(name, xalign=0.0, margin_start=8, tooltip_text=tooltip)
        combobox = ComboBoxText(false)

        choices = collect(keys(options))
        
        push!(combobox, choices...)

        index = Ahorn.setComboIndex!(combobox, collect(values(options)), value)

        return new(name, dataName, options, label, combobox, value)
    end
end

Base.size(option::DictionaryChoiceOption) = (2, 1)
getValue(option::DictionaryChoiceOption) = option.value
setValue!(option::DictionaryChoiceOption, value::Any) = Ahorn.setComboIndex(option.combobox, collect(values(options.options)), value, allowCustom=false)
getGroup(option::DictionaryChoiceOption) = 1
setGtkProperty!(option::DictionaryChoiceOption, field::Symbol, value::Any) = set_gtk_property!(option.combobox, field, value)
getGtkProperty(option::DictionaryChoiceOption, field::Symbol, typ::DataType) = set_gtk_property!(option.combobox, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::DictionaryChoiceOption, col::Integer=0, row::Integer=0)
    grid[col, row] = option.label
    grid[col + 1, row] = option.combobox

    @guarded signal_connect(option.combobox, "changed") do args...
        option.value = option.options[Gtk.bytestring(GAccessor.active_text(option.combobox))]
    end
end


struct CheckBoxOption <: Option
    name::String
    dataName::String

    checkbox::Gtk.GtkCheckButton

    function CheckBoxOption(name::String; dataName::String=name, tooltip::String="", value::Bool=false)
        checkbox = CheckButton(name, active=value, tooltip_text=tooltip)

        return new(name, dataName, checkbox)
    end
end

Base.size(option::CheckBoxOption) = (1, 1)
getValue(option::CheckBoxOption) = GAccessor.active(option.checkbox)
setValue!(option::CheckBoxOption, value::Bool) = GAccessor.active(option.checkbox, value)
getGroup(option::CheckBoxOption) = 2
setGtkProperty!(option::CheckBoxOption, field::Symbol, value::Any) = set_gtk_property!(option.checkbox, field, value)
getGtkProperty(option::CheckBoxOption, field::Symbol, typ::DataType) = set_gtk_property!(option.checkbox, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::CheckBoxOption, col::Integer=0, row::Integer=0)
    grid[col, row] = option.checkbox
end


struct SpinOption <: Option
    name::String
    dataName::String

    label::Gtk.GtkLabel
    spinButton::Gtk.GtkSpinButton

    function SpinOption(name::String, range::UnitRange{T}; dataName::String=name, tooltip::String="", value::T=first(range)) where T
        label = Label(name, xalign=0.0, margin_start=8, tooltip_text=tooltip)
        spinButton = SpinButton(range)

        GAccessor.value(spinButton, value)

        return new(name, dataName, label, spinButton)
    end
end

Base.size(option::SpinOption) = (1, 1)
getValue(option::SpinOption) = GAccessor.value(option.spinButton)
setValue!(option::SpinOption, value::Integer) = GAccessor.value(option.spinButton, value)
getGroup(option::SpinOption) = 0
setGtkProperty!(option::SpinOption, field::Symbol, value::Any) = set_gtk_property!(option.spinButton, field, value)
getGtkProperty(option::SpinOption, field::Symbol, typ::DataType) = set_gtk_property!(option.spinButton, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::SpinOption, col::Integer=0, row::Integer=0)
    grid[col, row] = option.label
    grid[col + 1, row] = option.spinButton
end

# TODO - Handle columns kwarg
struct ListOption <: Option
    name::String
    dataName::String

    container::Ahorn.ListContainer
    scrollable::Gtk.GtkScrolledWindow

    addButton::Gtk.GtkButton
    removeButton::Gtk.GtkButton

    editable::Bool

    minRows::Integer
    maxRows::Integer

    columns::Integer

    function ListOption(name::String, data::Array{T, 1}; dataName::String=name, tooltip::String="", editable::Bool=true, minRows::Integer=-1, maxRows::Integer=-1, columns::Integer=4) where T <: Tuple
        @Ahorn.catchall begin
            headers = tuple(string.(split(name, ';'))...)
            container = Ahorn.generateTreeView(headers, data, sortable=false, editable=fill(editable, length(headers)), callbacks=Array{Ahorn.listViewCallbackUnion, 1}(fill(columnEditCallback, length(headers))))
            scrollableWindow = ScrolledWindow(vexpand=true, hscrollbar_policy=Gtk.GtkPolicyType.NEVER)
            push!(scrollableWindow, container.tree)

            addButton = Button("Add row")
            removeButton = Button("Delete row")

            return new(name, dataName, container, scrollableWindow, addButton, removeButton, editable, minRows, maxRows, columns)
        end
    end
end

Base.size(option::ListOption) = (4, option.editable ? 2 : 1)
getValue(option::ListOption) = Ahorn.getListData(option.container)
setValue!(option::ListOption, value::Array{T, 1}) where T <: Tuple = Ahorn.updateTreeView(option.container, value)
getGroup(option::ListOption) = 4
setGtkProperty!(option::ListOption, field::Symbol, value::Any) = set_gtk_property!(option.tree, field, value)
getGtkProperty(option::ListOption, field::Symbol, typ::DataType) = set_gtk_property!(option.tree, field, typ)

function addToGrid!(grid::Gtk.GtkGrid, option::ListOption, col::Integer=0, row::Integer=0)
    rows, cols = Base.size(option.container.store)

    grid[col:col + 4, row] = option.scrollable

    if rows > 0
        Ahorn.selectRow!(option.container, 1)
    end

    if option.editable
        grid[col:col + 1, row + 1] = option.addButton
        grid[col + 2:col + 4, row + 1] = option.removeButton

        signal_connect(w -> addListRow(option), option.addButton, "clicked")
        signal_connect(w -> deleteListRow(option), option.removeButton, "clicked")
    end

    setListButtonSensitivity(option)
end


# Section Functions

function groupOptions(options::Array{Option, 1})
    groups = Dict{Integer, Array{Option, 1}}()

    for option in options
        group = getGroup(option)

        if !haskey(groups, group)
            groups[group] = Option[]
        end

        push!(groups[group], option)
    end

    return groups
end

function getOptionByDataName(options::Array{Option, 1}, name::String)
    index = findfirst(isequal(name), getfield.(options, :dataName))

    return index === nothing ? nothing : options[index]
end

function getOptionsData(options::Array{Option, 1})
    data = Dict{String, Any}()

    for option in options
        data[option.dataName] = getValue(option)
    end

    return data
end

function setOptionsData!(options::Array{Option, 1}, data::Dict{String, Any})
    for option in options
        if haskey(data, option.dataName)
            setValue!(option, data[option.dataName])
        end
    end
end

function getSectionData(section::Section)
    return getOptionsData(section.options)
end

function setSectionData!(section::Section, data::Dict{String, Any})
    return setOptionsData!(section.options, data)
end

function getSectionsData(sections::Array{Section, 1}, packIfSingleSection::Bool=false)
    if length(sections) == 1 && !packIfSingleSection
        return getSectionData(sections[1])
    end

    data = Dict{String, Dict{String, Any}}()

    for section in sections
        data[section.dataName] = getSectionData(section)
    end

    return data
end

function setSectionsData!(sections::Array{Section, 1}, data::Dict{String, Any})
    if length(sections) == 1
        if length(data) == 1 && isa(first(data)[2], Dict)
            setSectionData!(sections[1], first(data)[2])

        else
            setSectionData!(sections[1], data)
        end
    end

    data = Dict{String, Dict{String, Any}}()

    for section in sections
        setSectionData!(section, data[section.dataName])
    end
end

function addOption!(grid::Gtk.GtkGrid, option::Option, col::Integer, row::Integer, columns::Integer=4)
    needsCols, needsRows = size(option)

    if col + needsCols > columns
        row += 1
        col = 0
    end

    addToGrid!(grid, option, col, row)

    col += needsCols
    row += needsRows - 1

    return col, row
end

function generateSectionGrid(section::Section; columns::Integer=4, separateGroups::Bool=isempty(section.fieldOrder))
    grid = Grid()

    col = 0
    row = 0

    orderedOptions = filter((option) -> option.dataName in section.fieldOrder, section.options)
    sort!(orderedOptions, by=(option) -> findfirst(isequal(option.dataName), section.fieldOrder))

    for option in orderedOptions
        col, row = addOption!(grid, option, col, row, columns)
    end

    groups = groupOptions(section.options)

    for (group, options) in sort(collect(groups), by=g -> g[1])
        # Adding in front as this also covers orderedOptions, Grid won't display this as empty row
        if separateGroups
            row += 1
            col = 0
        end

        for option in sort(options, by=o -> o.name)
            # Already handled
            if option.dataName in section.fieldOrder
                continue
            end

            col, row = addOption!(grid, option, col, row, columns)
        end
    end

    return grid
end

function generateSectionsNotebook(sections::Array{Section, 1}; columns::Integer=4, separateGroups::Bool=true, gridIfSingleSection::Bool=true)
    useNotebook = length(sections) > 1
    notebook = Notebook()

    if gridIfSingleSection && !useNotebook
        return generateSectionGrid(sections[1], columns=columns, separateGroups=separateGroups)
    end

    for section in sections
        sectionGrid = generateSectionGrid(section, columns=columns, separateGroups=separateGroups)
        sectionBox = Box(:v)

        push!(sectionBox, sectionGrid)
        push!(notebook, sectionBox, section.name)
    end

    return notebook
end

# TODO - Better warning messages.
# What fields are wrong?
# Respect validation function
function createFormWindow(title::String, sections::Union{Array{Section, 1}, Section}; columns::Integer=4, separateGroups::Bool=true, gridIfSingleSection::Bool=true, buttonText::String="Update", callback::Function=(data) -> println(data), parent::Gtk.GtkWindow=Ahorn.window, icon::Pixbuf=Ahorn.windowIcon, canResize::Bool=false)
    sections = isa(sections, Section) ? Section[sections] : sections
    updateButton = Button(buttonText)

    @guarded signal_connect(updateButton, "clicked") do args...
        try
            data = getSectionsData(sections)
            callback(data)

        catch e
            println(Base.stderr, e)
            info_dialog("One or more of the inputs are invalid.\nPlease make sure number fields have valid numbers.", parent)
        end
    end

    content = generateSectionsNotebook(sections, columns=columns, separateGroups=separateGroups, gridIfSingleSection=gridIfSingleSection)

    window = Window(title, -1, -1, canResize, icon=icon) |> (Frame() |> (box = Box(:v)))
    push!(box, content)
    push!(box, updateButton)

    return window
end

function createFormWindow(title::String, options::Array{Option, 1}; columns::Integer=4, separateGroups::Bool=true, gridIfSingleSection::Bool=true, buttonText::String="Update", callback::Function=(data) -> println(data), parent::Gtk.GtkWindow=Ahorn.window)
    return createFormWindow(title, Section("section", options), columns=columns, fieldOrder=fieldOrder, separateGroups=separateGroups, gridIfSingleSection=gridIfSingleSection, buttonText=buttonText, callback=callback, parent=parent)
end

function suggestOption(displayName::String, value::Any; tooltip::String="", dataName::String=displayName, choices::Union{Array, Dict, Nothing}=nothing, editable::Bool=false)
    if isa(choices, Array)
        return TextChoiceOption(displayName, choices, dataName=dataName, tooltip=tooltip, value=value, editable=editable)
    
    elseif isa(choices, Dict)
        return DictionaryChoiceOption(displayName, choices, dataName=dataName, tooltip=tooltip, value=value)

    elseif isa(value, Bool)
        return CheckBoxOption(displayName, value=value, dataName=dataName, tooltip=tooltip)

    elseif isa(value, Char) || isa(value, String) || isa(value, Number)
        return TextEntryOption(displayName, value=string(value), dataName=dataName, as=typeof(value), tooltip=tooltip)

    elseif isa(value, Array) && !isempty(displayName)
        return ListOption(displayName, value, dataName=dataName, tooltip=tooltip, editable=editable)
    end
end

end