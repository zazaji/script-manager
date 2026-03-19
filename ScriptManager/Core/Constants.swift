// ScriptManager/Core/Constants.swift
import Foundation

public struct Constants {
    public struct UI {
        private static func localized(_ key: String, value: String) -> String {
            return AppLanguageManager.shared.localizedString(forKey: key, value: value)
        }
        
        public static var appTitle: String { localized("app_title", value: "Script Manager") }
        public static var permissionDeniedTitle: String { localized("permission_denied_title", value: "Permission Denied") }
        public static var permissionDeniedMessage: String { localized("permission_denied_message", value: "Full Disk Access is required.") }
        public static var fdaGuideMessage: String { localized("fda_guide_message", value: "Please grant Full Disk Access in System Settings.") }
        public static var revealAppInFinderButton: String { localized("reveal_app_in_finder_button", value: "Reveal in Finder") }
        
        public static var sandboxWarningTitle: String { localized("sandbox_warning_title", value: "Sandbox Warning") }
        public static var sandboxWarningMessage: String { localized("sandbox_warning_message", value: "App is running in Sandbox.") }
        
        public static var tccBugTitle: String { localized("tcc_bug_title", value: "TCC Bug Troubleshooting") }
        public static var tccBugDescription: String { localized("tcc_bug_description", value: "macOS TCC cache might be corrupted.") }
        public static var tccBugStep1: String { localized("tcc_bug_step1", value: "Remove app from Full Disk Access.") }
        public static var tccBugStep2: String { localized("tcc_bug_step2", value: "Run reset command in Terminal.") }
        public static var tccBugStep3: String { localized("tcc_bug_step3", value: "Add app back to Full Disk Access.") }
        public static var copyResetCommandButton: String { localized("copy_reset_command_button", value: "Copy Command") }
        public static var copiedToast: String { localized("copied_toast", value: "Copied!") }
        
        public static var selectWorkspaceButton: String { localized("select_workspace_button", value: "Select Workspace") }
        public static var emptyWorkspaceMessage: String { localized("empty_workspace_message", value: "No script selected or workspace is empty.") }
        public static var runScriptButton: String { localized("run_script_button", value: "Run") }
        public static var runningScriptButton: String { localized("running_script_button", value: "Running...") }
        public static var stopScriptButton: String { localized("stop_script_button", value: "Stop") }
        public static var parametersTitle: String { localized("parameters_title", value: "Parameters") }
        public static var consoleTitle: String { localized("console_title", value: "Console") }
        public static var selectFileButton: String { localized("select_file_button", value: "Select File") }
        public static var exampleLabel: String { localized("example_label", value: "Example:") }
        public static var parsingLabel: String { localized("parsing_label", value: "Parsing...") }
        public static var openSystemSettingsButton: String { localized("open_system_settings_button", value: "Open System Settings") }
        public static var checkAgainButton: String { localized("check_again_button", value: "Check Again") }
        public static var checkingPermissionsLabel: String { localized("checking_permissions_label", value: "Checking Permissions...") }
        public static var scriptLibraryTitle: String { localized("script_library_title", value: "Script Library") }
        
        public static var searchPrompt: String { localized("search_prompt", value: "Search scripts...") }
        public static var searchAppsPrompt: String { localized("search_apps_prompt", value: "Search applications...") }
        public static var clearLogsButton: String { localized("clear_logs_button", value: "Clear Logs") }
        public static var exportLogsButton: String { localized("export_logs_button", value: "Export Logs") }
        public static var openInFinderButton: String { localized("open_in_finder_button", value: "Open in Finder") }
        public static var openInEditorButton: String { localized("open_in_editor_button", value: "Open in Editor") }
        public static var requiredMark: String { localized("required_mark", value: "*") }
        public static var validationErrorMessage: String { localized("validation_error_message", value: "Validation Error") }
        public static var refreshWorkspaceTooltip: String { localized("refresh_workspace_tooltip", value: "Refresh Workspace") }
        
        public static var unnamedScript: String { localized("unnamed_script", value: "Unnamed Script") }
        public static var noDescription: String { localized("no_description", value: "No description available.") }
        public static var noExample: String { localized("no_example", value: "No example available.") }
        public static var pleaseInput: String { localized("please_input", value: "Please input") }
        
        public static var authorLabel: String { localized("author_label", value: "Author") }
        public static var versionLabel: String { localized("version_label", value: "Version") }
        
        public static var newScriptButton: String { localized("new_script_button", value: "New Script") }
        public static var newScriptTitle: String { localized("new_script_title", value: "Create New Script") }
        public static var scriptNamePlaceholder: String { localized("script_name_placeholder", value: "Script Name") }
        public static var scriptTypeLabel: String { localized("script_type_label", value: "Type") }
        public static var cancelButton: String { localized("cancel_button", value: "Cancel") }
        public static var createButton: String { localized("create_button", value: "Create") }
        public static var viewModeList: String { localized("view_mode_list", value: "List") }
        public static var viewModeGrid: String { localized("view_mode_grid", value: "Grid") }
        
        public static var editButton: String { localized("edit_button", value: "Edit") }
        public static var saveButton: String { localized("save_button", value: "Save") }
        public static var configurationTab: String { localized("configuration_tab", value: "Config") }
        public static var codeTab: String { localized("code_tab", value: "Code") }
        public static var terminalPanelTitle: String { localized("terminal_panel_title", value: "Terminal") }
        public static var closeTerminalButton: String { localized("close_terminal_button", value: "Close Terminal") }
        
        public static var additionalArgsPlaceholder: String { localized("additional_args_placeholder", value: "Additional Args...") }
        public static var recentWorkspaces: String { localized("recent_workspaces", value: "Recent Workspaces") }
        public static var frequentScripts: String { localized("frequent_scripts", value: "Frequent Scripts") }
        public static var customScripts: String { localized("custom_scripts", value: "Custom Scripts") }
        public static var addCustomScript: String { localized("add_custom_script", value: "Add Custom Script") }
        public static var settingsTitle: String { localized("settings_title", value: "Settings") }
        public static var themeLabel: String { localized("theme_label", value: "Theme") }
        public static var systemDefault: String { localized("system_default", value: "System") }
        public static var lightMode: String { localized("light_mode", value: "Light") }
        public static var darkMode: String { localized("dark_mode", value: "Dark") }
        
        public static var tabFrequent: String { localized("tab_frequent", value: "Frequent") }
        public static var tabCustom: String { localized("tab_custom", value: "Custom") }
        public static var tabWorkspace: String { localized("tab_workspace", value: "Workspace") }
        public static var tabApplications: String { localized("tab_applications", value: "Apps") }
        public static var applicationsTitle: String { localized("applications_title", value: "Applications") }
        
        public static var languageLabel: String { localized("language_label", value: "Language") }
        public static var restartRequiredMessage: String { localized("restart_required_message", value: "Please restart the app to apply language changes.") }
        
        public static var welcomeTitle: String { localized("welcome_title", value: "Welcome to Script Manager") }
        public static var welcomeSubtitle: String { localized("welcome_subtitle", value: "Manage, configure, and execute your scripts with an auto-generated UI.") }
        public static var featureAutoUITitle: String { localized("feature_auto_ui_title", value: "Auto UI Generation") }
        public static var featureAutoUIDesc: String { localized("feature_auto_ui_desc", value: "Extracts parameters from script comments automatically.") }
        public static var featureTerminalTitle: String { localized("feature_terminal_title", value: "Interactive Console") }
        public static var featureTerminalDesc: String { localized("feature_terminal_desc", value: "Full PTY support for interactive commands.") }
        public static var featureWorkspaceTitle: String { localized("feature_workspace_title", value: "Workspace Management") }
        public static var featureWorkspaceDesc: String { localized("feature_workspace_desc", value: "Organize scripts in folders with real-time file monitoring.") }
        public static var openWorkspaceButton: String { localized("open_workspace_button", value: "Open Workspace") }
        public static var generateSamplesButton: String { localized("generate_samples_button", value: "Generate Samples") }
        
        public static var deleteButton: String { localized("delete_button", value: "Delete") }
        public static var deleteConfirmTitle: String { localized("delete_confirm_title", value: "Confirm Delete") }
        public static var deleteConfirmMessage: String { localized("delete_confirm_message", value: "Are you sure you want to delete this script? This action cannot be undone.") }
        public static var removeButton: String { localized("remove_button", value: "Remove") }
        
        public static var noParametersRequired: String { localized("no_parameters_required", value: "No parameters required.") }
        public static var enterInputPrompt: String { localized("enter_input_prompt", value: "Enter input...") }
        public static var noActiveTerminals: String { localized("no_active_terminals", value: "No active terminals") }
        public static var okButton: String { localized("ok_button", value: "OK") }
        public static var environmentVariablesTitle: String { localized("environment_variables_title", value: "Environment Variables") }
        public static var addEnvVarButton: String { localized("add_env_var_button", value: "Add Variable") }
        public static var envVarNamePlaceholder: String { localized("env_var_name_placeholder", value: "Name") }
        public static var envVarValuePlaceholder: String { localized("env_var_value_placeholder", value: "Value") }
        public static var favoriteScripts: String { localized("favorite_scripts", value: "Favorite Scripts") }
        public static var addToFavorites: String { localized("add_to_favorites", value: "Add to Favorites") }
        public static var removeFromFavorites: String { localized("remove_from_favorites", value: "Remove from Favorites") }
        public static var tabFavorites: String { localized("tab_favorites", value: "Favorites") }
        
        public static var fdaRecommendedMessage: String { localized("fda_recommended_message", value: "Full Disk Access is recommended for full functionality.") }
        public static var grantAccessButton: String { localized("grant_access_button", value: "Grant Access") }
        
        public static var guideTitle: String { localized("guide_title", value: "How it works") }
        public static var guideStep1: String { localized("guide_step1", value: "1. Add comments like @Param to your script.") }
        public static var guideStep2: String { localized("guide_step2", value: "2. The app automatically generates a UI for them.") }
        public static var guideStep3: String { localized("guide_step3", value: "3. Click Run to execute with the configured parameters.") }
        
        public static var noEnvVarsConfigured: String { localized("no_env_vars_configured", value: "No environment variables configured.") }
        public static var processTerminatedByUser: String { localized("process_terminated_by_user", value: "\n⚠️[Process Terminated]: Canceled by user") }
        public static var processFinishedSuccess: String { localized("process_finished_success", value: "\n✅[Process Finished]: Success (Exit code 0)") }
        
        public static var pythonPathLabel: String { localized("python_path_label", value: "Python Path") }
        public static var nodePathLabel: String { localized("node_path_label", value: "Node.js Path") }
        public static var rubyPathLabel: String { localized("ruby_path_label", value: "Ruby Path") }
        public static var envPathLabel: String { localized("env_path_label", value: "Environment File (.bashrc/.zshrc)") }
        public static var defaultShellLabel: String { localized("default_shell_label", value: "Default Shell") }
        public static var selectPathButton: String { localized("select_path_button", value: "Select") }
        public static var templateOrSampleLabel: String { localized("template_or_sample_label", value: "Template / Sample") }
        public static var defaultTemplate: String { localized("default_template", value: "Default Template") }
        public static var blankScript: String { localized("blank_script", value: "Blank Script") }
        public static var generalSettings: String { localized("general_settings", value: "General") }
        public static var environmentPaths: String { localized("environment_paths", value: "Environment Paths") }
        
        public static var appPathLabel: String { localized("app_path_label", value: "Application Path") }
        public static var openAppButton: String { localized("open_app_button", value: "Open Application") }
        public static var appInfoTitle: String { localized("app_info_title", value: "Application Info") }

        public static func processFinishedFailure(_ code: String) -> String {
            return String(format: localized("process_finished_failure", value: "\n❌ [Process Finished]: Failure (Exit code %@)"), code)
        }
        
        public static func processStarted(_ name: String) -> String {
            return String(format: localized("process_started", value: "🚀 Start executing: %@"), name)
        }
        
        public static func executionError(_ error: String) -> String {
            return String(format: localized("execution_error", value: "❌ Execution error: %@"), error)
        }
    }

    public struct Permissions {
        public static let fullDiskAccessDescriptionKey = "NSFullDiskAccessUsageDescription"
    }

    public struct Keys {
        public static let appleEvents = "com.apple.security.automation.apple-events"
    }
}