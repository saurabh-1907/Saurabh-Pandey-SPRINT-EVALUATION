sap.ui.define(
    [
        "sap/ui/core/mvc/Controller",
        "sap/ui/model/json/JSONModel",
        "sap/ui/model/Filter",
        "sap/ui/model/FilterOperator",
        "sap/ui/core/format/NumberFormat",
        "sap/ui/core/format/DateFormat",
        "sap/m/MessageToast",
        "sap/m/MessageBox"
    ],
    function (Controller, JSONModel, Filter, FilterOperator, NumberFormat, DateFormat, MessageToast, MessageBox) {
        "use strict";

        const STANDARD_WEEK_HOURS = 40;   // only shown as a guide

        const amountFormat = NumberFormat.getFloatInstance({ maxFractionDigits: 2, groupingEnabled: true });
        const numberFormat = NumberFormat.getFloatInstance();
        const dayFormat = DateFormat.getDateInstance({ pattern: "d MMM" });
        const longDayFormat = DateFormat.getDateInstance({ pattern: "d MMM yyyy" });
        const todayFormat = DateFormat.getDateInstance({ pattern: "EEEE, d MMMM yyyy" });

        // OData values arrive formatted ("1,200.00"), KPI values as numbers
        const toNumber = (value) => {
            if (typeof value === "number") return value;
            return value ? numberFormat.parse(String(value)) || 0 : 0;
        };

        // "2026-10-26" -> Date (local midnight)
        const toDate = (iso) => (iso ? new Date(iso + "T00:00:00") : null);

        const addDays = (date, days) => new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);

        // the current week's timesheet in words (employee view)
        const WEEK_TEXT = {
            none:      { status: "Not started", state: "None",        icon: "sap-icon://status-inactive", action: "Log time",
                         hint: "You have not logged any time this week yet." },
            Draft:     { status: "Draft",       state: "Information", icon: "sap-icon://edit",            action: "Continue logging",
                         hint: "Your timesheet is a draft - add the remaining days and submit it." },
            Rejected:  { status: "Rejected",    state: "Error",       icon: "sap-icon://decline",         action: "Correct timesheet",
                         hint: "Your timesheet was rejected - please correct it and submit again." },
            Submitted: { status: "Submitted",   state: "Warning",     icon: "sap-icon://pending",         action: "View timesheet",
                         hint: "Submitted - waiting for approval." },
            Approved:  { status: "Approved",    state: "Success",     icon: "sap-icon://accept",          action: "View timesheet",
                         hint: "Approved - your hours are booked on the projects." },
            Invoiced:  { status: "Invoiced",    state: "Success",     icon: "sap-icon://receipt",         action: "View timesheet",
                         hint: "Approved and billed to the client." }
        };

        return Controller.extend("psa.home.controller.Home", {

            onInit: function () {
                this.getView().setModel(new JSONModel({ me: {}, kpi: {}, week: {}, apps: [] }), "home");
                this.load();
            },

            // ---------------- Data ----------------

            // who is logged in (whoAmI) + numbers (kpis), then fill the page for the role
            load: function () {
                const serviceUrl = this.getOwnerComponent().getModel().getServiceUrl();
                const get = (name) => fetch(serviceUrl + name, { headers: { Accept: "application/json" }, credentials: "same-origin" })
                    .then((response) => (response.ok ? response.json() : {}))
                    .catch(() => ({}));

                return Promise.all([get("whoAmI()"), get("kpis()")]).then(([me, kpi]) => {
                    const home = this.getView().getModel("home");
                    home.setProperty("/me", me);
                    home.setProperty("/kpi", kpi);
                    home.setProperty("/today", todayFormat.format(new Date()));
                    home.setProperty("/greeting", this.greeting(me.name));
                    home.setProperty("/week", this.weekInfo(kpi));
                    home.setProperty("/summary", this.summary(me, kpi));
                    home.setProperty("/apps", this.apps(me, kpi));
                    this.startLists(me, kpi);
                });
            },

            // lists are "suspended" in the view and only start for the right role
            startLists: function (me, kpi) {
                if (this._listsStarted) return;
                this._listsStarted = true;

                const resume = (id, filters) => {
                    const binding = this.byId(id).getBinding("items");
                    if (filters) binding.filter(filters);
                    binding.resume();
                };

                if (me.isAdmin) {
                    resume("approvals");
                    resume("projects");
                    resume("tasks", new Filter("STATUS", FilterOperator.NE, "Done"));
                    resume("alerts");
                } else if (kpi.myEmployeeID) {
                    resume("recent", new Filter("EMPLOYEE_ID", FilterOperator.EQ, kpi.myEmployeeID));
                }
            },

            refresh: function () {
                this.getView().getModel().refresh();
                return this.load();
            },

            // ---------------- Texts for the banner ----------------

            greeting: function (name) {
                const hour = new Date().getHours();
                const part = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";
                const first = String(name || "").split(" ")[0];
                return first ? part + ", " + first : part;
            },

            summary: function (me, kpi) {
                if (!kpi.myEmployeeID && !me.isAdmin) {
                    return "Your login is not linked to an employee yet - please ask an admin to add your e-mail in Employees.";
                }
                if (me.isAdmin) {
                    const open = (kpi.pendingApprovals || 0) + (kpi.atRiskBudgets || 0) + (kpi.atRiskTasks || 0) + (kpi.overdueInvoices || 0);
                    return open === 0
                        ? "Everything is on track - no approvals, risks or overdue invoices."
                        : open + (open === 1 ? " item needs" : " items need") + " your attention today.";
                }
                return this.getView().getModel("home").getProperty("/week/hint");
            },

            weekInfo: function (kpi) {
                const start = toDate(kpi.myWeekStart) || new Date();
                const end = addDays(start, 6);
                const text = WEEK_TEXT[kpi.myWeekStatus] || WEEK_TEXT.none;
                const hours = toNumber(kpi.myWeekHours);
                return Object.assign({}, text, {
                    label: dayFormat.format(start) + " - " + longDayFormat.format(end),
                    percent: Math.min(hours / STANDARD_WEEK_HOURS * 100, 100),
                    display: hours + " of " + STANDARD_WEEK_HOURS + " h"
                });
            },

            // app list of the role (same apps as the launchpad)
            apps: function (me, kpi) {
                const apps = [];
                const add = (title, description, icon, color, target, info, infoState) =>
                    apps.push({ title, description, icon, color, target, info: info || "", infoState: infoState || "None" });

                if (me.isAdmin) {
                    add("Approve Timesheets", "Approve or reject submitted weeks", "sap-icon://approvals", "Accent1",
                        "#Timesheet-approve", kpi.pendingApprovals ? kpi.pendingApprovals + " waiting" : "", "Warning");
                    add("Projects", "Budget, milestones and tasks", "sap-icon://project-definition-triangle-2", "Accent6",
                        "#Project-manage", kpi.atRiskBudgets ? kpi.atRiskBudgets + " at risk" : "", "Error");
                    add("Billing Workbench", "Generate, issue and track invoices", "sap-icon://receipt", "Accent7",
                        "#Invoice-manage", kpi.unbilledHours ? amountFormat.format(kpi.unbilledHours) + " h unbilled" : "", "Information");
                }
                add("My Timesheets", "Log hours and submit your week", "sap-icon://time-entry-request", "Accent8",
                    "#Timesheet-manage", kpi.myOpenTimesheets ? kpi.myOpenTimesheets + " open" : "", "Information");
                if (me.isAdmin) {
                    add("Clients", "Customer master data", "sap-icon://customer", "Accent9", "#Client-manage");
                    add("Employees", "People, rates and logins", "sap-icon://employee", "Accent10", "#Employee-manage");
                }
                return apps;
            },

            // ---------------- Navigation ----------------

            navigate: function (hash) {
                window.location.hash = hash;
            },

            onNavigate: function (event) {
                this.navigate(event.getSource().data("target"));
            },

            onAppPress: function (event) {
                this.navigate(event.getSource().getBindingContext("home").getProperty("target"));
            },

            openTimesheet: function (key, isActive) {
                this.navigate("#Timesheet-manage&/TimesheetSrv(NODE_KEY=" + key + ",IsActiveEntity=" + isActive + ")");
            },

            // open this week's timesheet, or start a new one (draft) for the current week
            onLogTime: function () {
                const kpi = this.getView().getModel("home").getProperty("/kpi");

                if (kpi.myWeekKey) {
                    this.openTimesheet(kpi.myWeekKey, !kpi.myWeekIsDraft);
                    return;
                }
                const context = this.getView().getModel().bindList("/TimesheetSrv").create({});
                context.created()
                    .then(() => this.openTimesheet(context.getProperty("NODE_KEY"), false))
                    .catch((error) => MessageBox.error(error.message));
            },

            onTimesheetPress: function (event) {
                this.openTimesheet(event.getSource().getBindingContext().getProperty("NODE_KEY"), true);
            },

            onApprovalPress: function (event) {
                this.navigate("#Timesheet-approve&/ApprovalSrv(" + event.getSource().getBindingContext().getProperty("NODE_KEY") + ")");
            },

            openProject: function (projectKey) {
                if (projectKey) {
                    this.navigate("#Project-manage&/ProjectSrv(NODE_KEY=" + projectKey + ",IsActiveEntity=true)");
                }
            },

            onProjectPress: function (event) {
                this.openProject(event.getSource().getBindingContext().getProperty("NODE_KEY"));
            },

            onTaskPress: function (event) {
                event.getSource().getBindingContext().requestProperty("MILESTONE/PROJECT_NODE_KEY")
                    .then((projectKey) => this.openProject(projectKey));
            },

            onAlertPress: function (event) {
                event.getSource().getBindingContext().requestProperty("PROJECT_NODE_KEY")
                    .then((projectKey) => this.openProject(projectKey));
            },

            // ---------------- Approve directly on the home page ----------------

            onApprove: function (event) {
                const context = event.getSource().getBindingContext();
                const name = context.getProperty("EMPLOYEE/fullName");
                const action = this.getView().getModel().bindContext("PSAService.approveTimesheet(...)", context);

                event.getSource().setEnabled(false);
                action.invoke()
                    .then(() => {
                        MessageToast.show("Timesheet of " + name + " approved - budget updated.");
                        return this.refresh();
                    })
                    .catch((error) => {
                        event.getSource().setEnabled(true);
                        MessageBox.error(error.message);
                    });
            },

            // ---------------- Formatters ----------------

            formatCount: function (value) {
                return value === null || value === undefined ? "–" : String(value);
            },

            formatAmount: function (value) {
                return value === null || value === undefined ? "–" : amountFormat.format(toNumber(value));
            },

            // progress bar: 0 - 100
            formatPercent: function (value) {
                return Math.min(Math.max(toNumber(value), 0), 100);
            },

            formatPercentText: function (value) {
                return Math.round(toNumber(value)) + " %";
            },

            formatHours: function (used, planned) {
                return toNumber(used) + " / " + toNumber(planned) + " h";
            },

            formatWeek: function (start, end) {
                const from = toDate(start);
                const to = toDate(end) || (from && addDays(from, 6));
                return from ? "Week " + dayFormat.format(from) + " - " + longDayFormat.format(to) : "";
            },

            formatInitials: function (name) {
                return String(name || "?").split(" ").map((part) => part.charAt(0)).join("").slice(0, 2).toUpperCase();
            },

            isRejected: function (status) {
                return status === "Rejected";
            },

            formatTimesheetState: function (status) {
                return (WEEK_TEXT[status] || WEEK_TEXT.none).state;
            },

            formatTimesheetIcon: function (status) {
                return (WEEK_TEXT[status] || WEEK_TEXT.none).icon;
            },

            formatBurnState: function (value) {
                const percent = toNumber(value);
                if (percent >= 100) return "Error";
                if (percent >= 80) return "Warning";
                return "Success";
            },

            formatBudgetState: function (status) {
                if (status === "Breached") return "Error";
                if (status === "At Risk") return "Warning";
                return "Success";
            },

            formatBudgetIcon: function (status) {
                if (status === "Breached") return "sap-icon://error";
                if (status === "At Risk") return "sap-icon://alert";
                return "sap-icon://sys-enter-2";
            }
        });
    }
);
