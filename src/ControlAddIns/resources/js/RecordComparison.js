/**
 * Data Debugger Record Comparison Control Add-in
 * Provides rich visual comparison of old vs new record data
 */

class RecordComparison {
    constructor() {
        this.container = null;
        this.config = {};
        this.currentData = null;
        this.filters = {};
        this.viewMode = 'diff'; // 'diff', 'table', 'side-by-side'
        this.selectedField = null;
        this.diffPatcher = null;
        this.initialized = false;
        
        // Wait for jsondiffpatch to be available
        this.waitForDependencies().then(() => {
            this.initializeDiffPatcher();
            this.init();
        });
    }

    async waitForDependencies() {
        // Wait for jsondiffpatch to be available
        let attempts = 0;
        const maxAttempts = 50; // 5 seconds max wait
        
        while (typeof jsondiffpatch === 'undefined' && attempts < maxAttempts) {
            await new Promise(resolve => setTimeout(resolve, 100));
            attempts++;
        }
        
        if (typeof jsondiffpatch === 'undefined') {
            console.error('jsondiffpatch library failed to load');
            throw new Error('jsondiffpatch library is not available');
        }
        
        console.log('jsondiffpatch library loaded successfully');
    }

    initializeDiffPatcher() {
        try {
            this.diffPatcher = jsondiffpatch.create({
                objectHash: function(obj, index) {
                    return obj.name || obj.id || obj._id || '$$index:' + index;
                },
                arrays: {
                    detectMove: true,
                    includeValueOnMove: false
                },
                textDiff: {
                    minLength: 60
                }
            });
            console.log('DiffPatcher initialized successfully');
        } catch (error) {
            console.error('Failed to initialize DiffPatcher:', error);
            throw error;
        }
    }

    init() {
        this.createContainer();
        this.setupEventHandlers();
        this.initialized = true;
        console.log('RecordComparison initialized successfully');
    }

    initialize(configStr) {
        // Allow reinitialization with new config
        try {
            this.config = JSON.parse(configStr);
            this.updateTitle();
            console.log('Configuration updated:', this.config);
        } catch (e) {
            console.error('Invalid configuration:', e);
        }
    }

    createContainer() {
        document.body.innerHTML = '';
        
        this.container = document.createElement('div');
        this.container.className = 'record-comparison-container';
        this.container.innerHTML = `
            <div class="comparison-header">
                <div class="header-title">
                    <h2>Record Comparison Viewer</h2>
                    <div class="record-info"></div>
                </div>
                <div class="header-controls">
                    <div class="filter-controls">
                        <select id="changeTypeFilter" class="filter-select">
                            <option value="all">All Changes</option>
                            <option value="modified">Modified Fields</option>
                            <option value="added">Added Fields</option>
                            <option value="removed">Removed Fields</option>
                        </select>
                        <input type="text" id="fieldSearchFilter" placeholder="Search fields..." class="filter-input">
                        <button id="clearFilters" class="btn btn-secondary">Clear Filters</button>
                    </div>
                    <div class="view-controls">
                        <select id="viewModeSelector" class="filter-select">
                            <option value="diff">Diff View</option>
                            <option value="table">Table View</option>
                            <option value="side-by-side">Side by Side</option>
                        </select>
                    </div>
                    <div class="action-controls">
                        <button id="exportHtml" class="btn btn-primary">Export HTML</button>
                        <button id="exportJson" class="btn btn-primary">Export JSON</button>
                        <button id="collapseAll" class="btn btn-secondary">Collapse All</button>
                        <button id="expandAll" class="btn btn-secondary">Expand All</button>
                    </div>
                </div>
            </div>
            <div class="comparison-content">
                <div class="comparison-stats">
                    <div class="stat-item">
                        <span class="stat-label">Total Fields:</span>
                        <span class="stat-value" id="totalFields">0</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Modified:</span>
                        <span class="stat-value modified" id="modifiedFields">0</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Added:</span>
                        <span class="stat-value added" id="addedFields">0</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Removed:</span>
                        <span class="stat-value removed" id="removedFields">0</span>
                    </div>
                </div>
                <div class="comparison-viewer" id="comparisonViewer">
                    <div class="no-data-message">
                        <div class="no-data-icon">📊</div>
                        <h3>No Comparison Data</h3>
                        <p>Load record comparison data to see the differences between old and new values.</p>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(this.container);
    }

    setupEventHandlers() {
        // Filter controls
        document.getElementById('changeTypeFilter').addEventListener('change', (e) => {
            this.applyFilter('changeType', e.target.value);
        });

        document.getElementById('fieldSearchFilter').addEventListener('input', (e) => {
            this.applyFilter('search', e.target.value);
        });

        document.getElementById('clearFilters').addEventListener('click', () => {
            this.clearFilters();
        });

        // Action controls
        document.getElementById('exportHtml').addEventListener('click', () => {
            this.exportData('html');
        });

        document.getElementById('exportJson').addEventListener('click', () => {
            this.exportData('json');
        });

        document.getElementById('collapseAll').addEventListener('click', () => {
            this.toggleAllSections(false);
        });

        document.getElementById('expandAll').addEventListener('click', () => {
            this.toggleAllSections(true);
        });

        // View mode selector
        document.getElementById('viewModeSelector').addEventListener('change', (e) => {
            this.viewMode = e.target.value;
            this.renderCurrentView();
        });
    }

    initialize(configStr) {
        try {
            this.config = JSON.parse(configStr);
            this.updateTitle();
        } catch (e) {
            console.error('Invalid configuration:', e);
        }
    }

    loadComparison(oldDataStr, newDataStr, metadataStr) {
        try {
            const oldData = JSON.parse(oldDataStr || '{}');
            const newData = JSON.parse(newDataStr || '{}');
            const metadata = JSON.parse(metadataStr || '{}');

            this.currentData = {
                old: oldData,
                new: newData,
                metadata: metadata
            };

            this.renderComparison();
            this.updateStats();
        } catch (e) {
            console.error('Error loading comparison data:', e);
            this.showError('Failed to load comparison data: ' + e.message);
        }
    }

    loadMultipleComparisons(comparisonsStr) {
        try {
            const comparisons = JSON.parse(comparisonsStr);
            this.renderMultipleComparisons(comparisons);
        } catch (e) {
            console.error('Error loading multiple comparisons:', e);
            this.showError('Failed to load comparison data: ' + e.message);
        }
    }

    renderComparison() {
        this.updateRecordInfo();
        this.renderCurrentView();
    }

    updateRecordInfo() {
        const recordInfo = document.querySelector('.record-info');
        if (recordInfo && this.currentData && this.currentData.metadata) {
            const meta = this.currentData.metadata;
            recordInfo.innerHTML = `
                <div class="record-meta">
                    <span class="meta-item"><strong>Table:</strong> ${meta.tableName || 'Unknown'} (${meta.tableId || 'N/A'})</span>
                    <span class="meta-item"><strong>Primary Key:</strong> ${meta.primaryKey || 'N/A'}</span>
                    <span class="meta-item"><strong>Change Type:</strong> ${meta.changeType || 'N/A'}</span>
                </div>
            `;
        }
    }

    renderCurrentView() {
        if (!this.currentData || !this.diffPatcher) return;

        const viewer = document.getElementById('comparisonViewer');
        const delta = this.diffPatcher.diff(this.currentData.old, this.currentData.new);

        if (!delta) {
            viewer.innerHTML = `
                <div class="no-changes-message">
                    <div class="no-changes-icon">✅</div>
                    <h3>No Changes Detected</h3>
                    <p>The old and new record data are identical.</p>
                </div>
            `;
            return;
        }

        switch (this.viewMode) {
            case 'table':
                this.renderTableView(delta, viewer);
                break;
            case 'side-by-side':
                this.renderSideBySideView(delta, viewer);
                break;
            default:
                this.renderDiffView(delta, viewer);
        }
    }

    renderDiffView(delta, viewer) {
        // Create custom HTML formatter for better field-level display
        const html = this.createCustomDiffHtml(delta, this.currentData.metadata);
        viewer.innerHTML = html;
        this.setupDiffInteractions();
    }

    renderTableView(delta, viewer) {
        const changes = this.extractChangesForTable(delta);
        
        let html = `
            <div class="table-view">
                <table class="comparison-table">
                    <thead>
                        <tr>
                            <th>Field Name</th>
                            <th>Data Type</th>
                            <th>Old Value</th>
                            <th>New Value</th>
                            <th>Change Type</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
        `;

        changes.forEach(change => {
            const fieldMeta = this.currentData.metadata.fields && this.currentData.metadata.fields[change.fieldName] || {};
            const changeTypeClass = `change-${change.changeType}`;
            
            html += `
                <tr class="table-row ${changeTypeClass}" data-field="${change.fieldName}">
                    <td class="field-name-cell">
                        <div class="field-display-name">${fieldMeta.caption || change.fieldName}</div>
                        <div class="field-technical-name">${change.fieldName}</div>
                    </td>
                    <td class="data-type-cell">${fieldMeta.type || 'Unknown'}</td>
                    <td class="old-value-cell ${change.changeType === 'modified' || change.changeType === 'removed' ? 'value-changed-red' : ''}">
                        ${change.oldValue !== null ? this.formatTableValue(change.oldValue, fieldMeta) : '<em>-</em>'}
                    </td>
                    <td class="new-value-cell ${change.changeType === 'modified' || change.changeType === 'added' ? 'value-changed-red' : ''}">
                        ${change.newValue !== null ? this.formatTableValue(change.newValue, fieldMeta) : '<em>-</em>'}
                    </td>
                    <td class="change-type-cell">
                        <span class="change-badge ${changeTypeClass}">${this.getChangeLabel(change.changeType)}</span>
                    </td>
                    <td class="actions-cell">
                        <button class="drill-down-btn" onclick="drillDownField('${change.fieldName}')" title="View Details">🔍</button>
                        <button class="select-field-btn" onclick="selectTableField('${change.fieldName}')" title="Select Field">📌</button>
                    </td>
                </tr>
            `;
        });

        html += `
                    </tbody>
                </table>
            </div>
        `;

        viewer.innerHTML = html;
        this.setupTableInteractions();
    }

    renderSideBySideView(delta, viewer) {
        const changes = this.extractChangesForTable(delta);
        
        let html = `
            <div class="side-by-side-view">
                <div class="side-panel old-panel">
                    <h3>Original Record</h3>
                    <div class="record-fields">
        `;

        changes.forEach(change => {
            const fieldMeta = this.currentData.metadata.fields && this.currentData.metadata.fields[change.fieldName] || {};
            const isChanged = change.changeType !== 'added';
            
            html += `
                <div class="side-field ${isChanged && change.changeType !== 'unchanged' ? 'field-highlight' : ''}" data-field="${change.fieldName}">
                    <label class="side-field-label">${fieldMeta.caption || change.fieldName}:</label>
                    <div class="side-field-value ${isChanged && change.changeType === 'modified' ? 'value-changed-red' : ''}">
                        ${change.oldValue !== null ? this.formatTableValue(change.oldValue, fieldMeta) : '<em>-</em>'}
                    </div>
                </div>
            `;
        });

        html += `
                    </div>
                </div>
                <div class="side-panel new-panel">
                    <h3>Modified Record</h3>
                    <div class="record-fields">
        `;

        changes.forEach(change => {
            const fieldMeta = this.currentData.metadata.fields && this.currentData.metadata.fields[change.fieldName] || {};
            const isChanged = change.changeType !== 'removed';
            
            html += `
                <div class="side-field ${isChanged && change.changeType !== 'unchanged' ? 'field-highlight' : ''}" data-field="${change.fieldName}">
                    <label class="side-field-label">${fieldMeta.caption || change.fieldName}:</label>
                    <div class="side-field-value ${isChanged && change.changeType === 'modified' ? 'value-changed-red' : ''}">
                        ${change.newValue !== null ? this.formatTableValue(change.newValue, fieldMeta) : '<em>-</em>'}
                    </div>
                </div>
            `;
        });

        html += `
                    </div>
                </div>
            </div>
        `;

        viewer.innerHTML = html;
        this.setupSideInteractions();
    }

    extractChangesForTable(delta) {
        const changes = [];
        
        for (const [fieldName, fieldDelta] of Object.entries(delta)) {
            if (fieldName.startsWith('_')) continue; // Skip jsondiffpatch metadata

            const changeType = this.getChangeType(fieldDelta);
            let oldValue = null, newValue = null;

            switch (changeType) {
                case 'modified':
                    oldValue = fieldDelta[0];
                    newValue = fieldDelta[1];
                    break;
                case 'added':
                    newValue = fieldDelta[0];
                    oldValue = this.currentData.old[fieldName] || null;
                    break;
                case 'removed':
                    oldValue = fieldDelta[0];
                    newValue = null;
                    break;
            }

            changes.push({
                fieldName,
                changeType,
                oldValue,
                newValue
            });
        }

        return changes.sort((a, b) => {
            // Sort by change type priority, then by field name
            const priority = { 'modified': 0, 'added': 1, 'removed': 2 };
            if (priority[a.changeType] !== priority[b.changeType]) {
                return priority[a.changeType] - priority[b.changeType];
            }
            return a.fieldName.localeCompare(b.fieldName);
        });
    }

    formatTableValue(value, fieldMeta) {
        if (value === null || value === undefined) return '<em class="null-value">null</em>';
        if (value === '') return '<em class="empty-value">empty</em>';
        
        // Apply formatting based on field type and truncate long values
        let formatted = this.formatValue(value, fieldMeta);
        
        // Truncate long values for table display
        if (formatted.length > 50) {
            return `<span class="truncated-value" title="${formatted}">${formatted.substring(0, 47)}...</span>`;
        }
        
        return formatted;
    }

    setupTableInteractions() {
        // Make table rows clickable
        document.querySelectorAll('.table-row').forEach(row => {
            row.addEventListener('click', (e) => {
                if (!e.target.classList.contains('drill-down-btn') && !e.target.classList.contains('select-field-btn')) {
                    const fieldName = row.getAttribute('data-field');
                    this.highlightTableField(fieldName);
                }
            });
        });

        // Global functions for button clicks
        window.drillDownField = (fieldName) => {
            this.showFieldDrillDown(fieldName);
        };

        window.selectTableField = (fieldName) => {
            this.selectField(fieldName);
        };
    }

    setupSideInteractions() {
        document.querySelectorAll('.side-field').forEach(field => {
            field.addEventListener('click', (e) => {
                const fieldName = field.getAttribute('data-field');
                this.highlightSideField(fieldName);
            });
        });
    }

    highlightTableField(fieldName) {
        // Remove previous highlights
        document.querySelectorAll('.table-row').forEach(row => {
            row.classList.remove('row-selected');
        });

        // Highlight selected row
        const selectedRow = document.querySelector(`tr[data-field="${fieldName}"]`);
        if (selectedRow) {
            selectedRow.classList.add('row-selected');
            this.selectedField = fieldName;
        }
    }

    highlightSideField(fieldName) {
        // Remove previous highlights
        document.querySelectorAll('.side-field').forEach(field => {
            field.classList.remove('field-selected');
        });

        // Highlight selected fields in both panels
        document.querySelectorAll(`[data-field="${fieldName}"]`).forEach(field => {
            field.classList.add('field-selected');
        });

        this.selectedField = fieldName;
    }

    showFieldDrillDown(fieldName) {
        const fieldInfo = this.getFieldDetailInfo(fieldName);
        
        // Create drill-down data for AL
        const drillDownData = {
            fieldName: fieldName,
            fieldInfo: fieldInfo,
            action: 'drill-down'
        };
        
        // Trigger AL event to open drill-down page
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnFieldSelected', [JSON.stringify(drillDownData)]);
    }

    getFieldDetailInfo(fieldName) {
        const fieldMeta = this.currentData.metadata.fields && this.currentData.metadata.fields[fieldName] || {};
        const oldValue = this.currentData.old[fieldName];
        const newValue = this.currentData.new[fieldName];
        
        return {
            caption: fieldMeta.caption || fieldName,
            dataType: fieldMeta.type || 'Unknown',
            oldValue: oldValue,
            newValue: newValue,
            changeType: this.determineChangeType(oldValue, newValue),
            tooltip: fieldMeta.tooltip || '',
            length: fieldMeta.length || 0
        };
    }

    determineChangeType(oldValue, newValue) {
        if (oldValue === undefined && newValue !== undefined) return 'added';
        if (oldValue !== undefined && newValue === undefined) return 'removed';
        if (oldValue !== newValue) return 'modified';
        return 'unchanged';
    }

    selectField(fieldName) {
        const fieldInfo = this.getFieldDetailInfo(fieldName);
        
        const selectionData = {
            fieldName: fieldName,
            fieldInfo: fieldInfo,
            action: 'select'
        };
        
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnFieldSelected', [JSON.stringify(selectionData)]);
    }

    createCustomDiffHtml(delta, metadata) {
        let html = '<div class="field-comparisons">';
        
        for (const [fieldName, fieldDelta] of Object.entries(delta)) {
            if (fieldName.startsWith('_')) continue; // Skip jsondiffpatch metadata

            const fieldMeta = metadata.fields && metadata.fields[fieldName] || {};
            const changeType = this.getChangeType(fieldDelta);
            
            html += `
                <div class="field-comparison ${changeType}" data-field="${fieldName}">
                    <div class="field-header" onclick="toggleFieldDetails('${fieldName}')">
                        <div class="field-info">
                            <span class="field-name">${fieldMeta.caption || fieldName}</span>
                            <span class="field-type">${fieldMeta.type || 'Unknown'}</span>
                            <span class="change-indicator ${changeType}">${this.getChangeLabel(changeType)}</span>
                        </div>
                        <div class="field-actions">
                            <button class="btn-icon" onclick="selectField('${fieldName}')" title="Select this field">
                                <span>🔍</span>
                            </button>
                            <button class="btn-icon toggle-btn" title="Toggle details">
                                <span>▼</span>
                            </button>
                        </div>
                    </div>
                    <div class="field-details" id="details-${fieldName}">
                        ${this.createFieldValueComparison(fieldName, fieldDelta, fieldMeta)}
                    </div>
                </div>
            `;
        }
        
        html += '</div>';
        return html;
    }

    createFieldValueComparison(fieldName, fieldDelta, fieldMeta) {
        const changeType = this.getChangeType(fieldDelta);
        let html = '<div class="value-comparison">';

        switch (changeType) {
            case 'modified':
                html += `
                    <div class="value-row">
                        <div class="value-label">Old Value:</div>
                        <div class="value-content old-value">${this.formatValue(fieldDelta[0], fieldMeta)}</div>
                    </div>
                    <div class="value-row">
                        <div class="value-label">New Value:</div>
                        <div class="value-content new-value">${this.formatValue(fieldDelta[1], fieldMeta)}</div>
                    </div>
                `;
                break;
            case 'added':
                html += `
                    <div class="value-row">
                        <div class="value-label">Added Value:</div>
                        <div class="value-content new-value">${this.formatValue(fieldDelta[0], fieldMeta)}</div>
                    </div>
                `;
                break;
            case 'removed':
                html += `
                    <div class="value-row">
                        <div class="value-label">Removed Value:</div>
                        <div class="value-content old-value">${this.formatValue(fieldDelta[0], fieldMeta)}</div>
                    </div>
                `;
                break;
        }

        if (fieldMeta.tooltip) {
            html += `<div class="field-tooltip">${fieldMeta.tooltip}</div>`;
        }

        html += '</div>';
        return html;
    }

    getChangeType(fieldDelta) {
        if (Array.isArray(fieldDelta)) {
            if (fieldDelta.length === 2) return 'modified';
            if (fieldDelta.length === 1) return 'added';
            if (fieldDelta.length === 3 && fieldDelta[2] === 0) return 'removed';
        }
        return 'unknown';
    }

    getChangeLabel(changeType) {
        switch (changeType) {
            case 'modified': return 'Modified';
            case 'added': return 'Added';
            case 'removed': return 'Removed';
            default: return 'Changed';
        }
    }

    formatValue(value, fieldMeta) {
        if (value === null || value === undefined) return '<em>null</em>';
        if (value === '') return '<em>empty</em>';
        
        // Apply formatting based on field type
        switch (fieldMeta.type) {
            case 'DateTime':
                return new Date(value).toLocaleString();
            case 'Date':
                return new Date(value).toLocaleDateString();
            case 'Boolean':
                return value ? '✓ Yes' : '✗ No';
            case 'Decimal':
                return parseFloat(value).toLocaleString();
            case 'Integer':
                return parseInt(value).toLocaleString();
            default:
                return String(value);
        }
    }

    setupDiffInteractions() {
        // Make field selections interactive
        window.toggleFieldDetails = (fieldName) => {
            const details = document.getElementById(`details-${fieldName}`);
            const toggleBtn = details.parentElement.querySelector('.toggle-btn span');
            
            if (details.style.display === 'none') {
                details.style.display = 'block';
                toggleBtn.textContent = '▲';
            } else {
                details.style.display = 'none';
                toggleBtn.textContent = '▼';
            }
        };

        window.selectField = (fieldName) => {
            const fieldInfo = {
                fieldName: fieldName,
                metadata: this.currentData.metadata.fields && this.currentData.metadata.fields[fieldName]
            };
            
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnFieldSelected', [JSON.stringify(fieldInfo)]);
        };
    }

    applyFilter(filterType, value) {
        this.filters[filterType] = value;
        
        const fields = document.querySelectorAll('.field-comparison');
        fields.forEach(field => {
            let show = true;
            
            // Apply change type filter
            if (this.filters.changeType && this.filters.changeType !== 'all') {
                if (!field.classList.contains(this.filters.changeType)) {
                    show = false;
                }
            }
            
            // Apply search filter
            if (this.filters.search && this.filters.search.trim()) {
                const fieldName = field.dataset.field.toLowerCase();
                const searchTerm = this.filters.search.toLowerCase();
                if (!fieldName.includes(searchTerm)) {
                    show = false;
                }
            }
            
            field.style.display = show ? 'block' : 'none';
        });

        // Update stats based on visible fields
        this.updateVisibleStats();
        
        // Notify AL about filter changes
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnFiltersChanged', [JSON.stringify(this.filters)]);
    }

    clearFilters() {
        this.filters = {};
        document.getElementById('changeTypeFilter').value = 'all';
        document.getElementById('fieldSearchFilter').value = '';
        
        const fields = document.querySelectorAll('.field-comparison');
        fields.forEach(field => {
            field.style.display = 'block';
        });
        
        this.updateStats();
    }

    updateStats() {
        if (!this.currentData) return;

        const fields = document.querySelectorAll('.field-comparison');
        let total = 0, modified = 0, added = 0, removed = 0;

        fields.forEach(field => {
            total++;
            if (field.classList.contains('modified')) modified++;
            if (field.classList.contains('added')) added++;
            if (field.classList.contains('removed')) removed++;
        });

        document.getElementById('totalFields').textContent = total;
        document.getElementById('modifiedFields').textContent = modified;
        document.getElementById('addedFields').textContent = added;
        document.getElementById('removedFields').textContent = removed;
    }

    updateVisibleStats() {
        const visibleFields = document.querySelectorAll('.field-comparison:not([style*="display: none"])');
        let total = 0, modified = 0, added = 0, removed = 0;

        visibleFields.forEach(field => {
            total++;
            if (field.classList.contains('modified')) modified++;
            if (field.classList.contains('added')) added++;
            if (field.classList.contains('removed')) removed++;
        });

        document.getElementById('totalFields').textContent = total;
        document.getElementById('modifiedFields').textContent = modified;
        document.getElementById('addedFields').textContent = added;
        document.getElementById('removedFields').textContent = removed;
    }

    toggleAllSections(expand) {
        const details = document.querySelectorAll('.field-details');
        const toggleBtns = document.querySelectorAll('.toggle-btn span');
        
        details.forEach((detail, index) => {
            detail.style.display = expand ? 'block' : 'none';
            if (toggleBtns[index]) {
                toggleBtns[index].textContent = expand ? '▲' : '▼';
            }
        });
    }

    exportData(format) {
        let exportData = '';
        
        switch (format) {
            case 'html':
                exportData = this.container.innerHTML;
                break;
            case 'json':
                exportData = JSON.stringify({
                    comparison: this.currentData,
                    filters: this.filters,
                    timestamp: new Date().toISOString()
                }, null, 2);
                break;
            case 'text':
                exportData = this.createTextExport();
                break;
        }
        
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnExportReady', [exportData]);
    }

    createTextExport() {
        let text = 'Record Comparison Report\n';
        text += '========================\n\n';
        
        const fields = document.querySelectorAll('.field-comparison:not([style*="display: none"])');
        fields.forEach(field => {
            const fieldName = field.dataset.field;
            const changeType = field.className.match(/(modified|added|removed)/)?.[1] || 'unknown';
            
            text += `Field: ${fieldName}\n`;
            text += `Change Type: ${changeType}\n`;
            
            const valueRows = field.querySelectorAll('.value-row');
            valueRows.forEach(row => {
                const label = row.querySelector('.value-label').textContent;
                const value = row.querySelector('.value-content').textContent;
                text += `${label} ${value}\n`;
            });
            
            text += '\n';
        });
        
        return text;
    }

    updateTitle() {
        const titleElement = this.container.querySelector('.header-title h2');
        if (this.config.title) {
            titleElement.textContent = this.config.title;
        }
    }

    showError(message) {
        const viewer = document.getElementById('comparisonViewer');
        viewer.innerHTML = `
            <div class="error-message">
                <div class="error-icon">⚠️</div>
                <h3>Error</h3>
                <p>${message}</p>
            </div>
        `;
    }

    clearData() {
        this.currentData = null;
        this.filters = {};
        const viewer = document.getElementById('comparisonViewer');
        viewer.innerHTML = `
            <div class="no-data-message">
                <div class="no-data-icon">📊</div>
                <h3>No Comparison Data</h3>
                <p>Load record comparison data to see the differences between old and new values.</p>
            </div>
        `;
        this.updateStats();
    }
}

// Global instance
let recordComparison;

// AL Control Add-in interface functions
Microsoft.Dynamics.NAV.InvokeExtensibilityMethod = Microsoft.Dynamics.NAV.InvokeExtensibilityMethod || function() {};

function Initialize(config) {
    if (!recordComparison) {
        recordComparison = new RecordComparison();
    }
    
    // Wait for initialization to complete
    const waitForInit = () => {
        if (recordComparison.initialized) {
            recordComparison.initialize(config);
        } else {
            setTimeout(waitForInit, 100);
        }
    };
    
    waitForInit();
}

function LoadComparison(oldData, newData, metadata) {
    if (!recordComparison) {
        recordComparison = new RecordComparison();
    }
    
    // Wait for initialization to complete
    const waitForInit = () => {
        if (recordComparison.initialized) {
            recordComparison.loadComparison(oldData, newData, metadata);
        } else {
            setTimeout(waitForInit, 100);
        }
    };
    
    waitForInit();
}

function LoadMultipleComparisons(comparisons) {
    if (!recordComparison) {
        recordComparison = new RecordComparison();
    }
    recordComparison.loadMultipleComparisons(comparisons);
}

function ApplyFilters(filters) {
    if (recordComparison) {
        recordComparison.applyFilter('custom', JSON.parse(filters));
    }
}

function ExportComparison(format) {
    if (recordComparison) {
        recordComparison.exportData(format);
    }
}

function ClearData() {
    if (recordComparison) {
        recordComparison.clearData();
    }
}
