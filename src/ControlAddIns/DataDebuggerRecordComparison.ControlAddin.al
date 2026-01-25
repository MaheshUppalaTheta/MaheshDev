controladdin "Data Debugger Record Comparison"
{
    RequestedHeight = 600;
    RequestedWidth = 1200;
    MinimumHeight = 400;
    MinimumWidth = 800;
    MaximumHeight = 1000;
    MaximumWidth = 1600;
    VerticalStretch = true;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    Scripts = 'https://unpkg.com/jsondiffpatch@0.4.1/dist/jsondiffpatch.umd.min.js',
              'src/ControlAddIns/resources/js/RecordComparison.js';

    StyleSheets = 'https://unpkg.com/jsondiffpatch@0.4.1/dist/formatters-styles/html.css',
                  'src/ControlAddIns/resources/css/RecordComparison.css';

    StartupScript = 'src/ControlAddIns/resources/js/Startup.js';

    /// <summary>
    /// Initialize the comparison viewer with configuration
    /// </summary>
    /// <param name="config">JSON string containing configuration options</param>
    procedure Initialize(config: Text);

    /// <summary>
    /// Load comparison data for a single record
    /// </summary>
    /// <param name="oldData">JSON string of the old record data</param>
    /// <param name="newData">JSON string of the new record data</param>
    /// <param name="metadata">JSON string containing field metadata (types, captions, etc.)</param>
    procedure LoadComparison(oldData: Text; newData: Text; metadata: Text);

    /// <summary>
    /// Load comparison data for multiple records
    /// </summary>
    /// <param name="comparisons">JSON array of comparison objects</param>
    procedure LoadMultipleComparisons(comparisons: Text);

    /// <summary>
    /// Apply filters to show only specific types of changes
    /// </summary>
    /// <param name="filters">JSON string with filter criteria</param>
    procedure ApplyFilters(filters: Text);

    /// <summary>
    /// Export the current comparison view
    /// </summary>
    /// <param name="format">Export format: 'html', 'json', 'text'</param>
    procedure ExportComparison(format: Text);

    /// <summary>
    /// Clear all comparison data
    /// </summary>
    procedure ClearData();

    /// <summary>
    /// Event triggered when user selects a specific field change
    /// </summary>
    /// <param name="fieldInfo">JSON string with field information</param>
    event OnFieldSelected(fieldInfo: Text);

    /// <summary>
    /// Event triggered when user requests to view related records
    /// </summary>
    /// <param name="relationInfo">JSON string with relation information</param>
    event OnViewRelatedRecords(relationInfo: Text);

    /// <summary>
    /// Event triggered when export is ready
    /// </summary>
    /// <param name="exportData">Exported data in requested format</param>
    event OnExportReady(exportData: Text);

    /// <summary>
    /// Event triggered when user applies custom filters
    /// </summary>
    /// <param name="filterCriteria">JSON string with filter criteria</param>
    event OnFiltersChanged(filterCriteria: Text);
}
