# Redmine QuickBooks Line Items

A plugin for Redmine that extends the functionality of the [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) plugin.

This plugin allows **billable line items** to be attached to a Redmine issue. When the issue is closed, the plugin automatically generates a **QuickBooks Online estimate** containing those line items.

---

## Requirements

*   **Redmine:** 6.1+
    
*   **Ruby:** 3.2+
    
*   **Parent Plugin:** [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) (must be installed and configured)
    

---

## Compatibility

| Plugin Version | Redmine Version | Ruby Version |
| --- | --- | --- |
| 2026.3.5+ | 6.1.x | 3.2+ |

---

## Features

*   **Billable Line Items:** Attach billable products or services directly to any Redmine issue.
    
*   **Automated Estimate Creation:** Automatically generates a **QuickBooks Online Estimate** when an issue is closed, streamlining the billing workflow.
    

### Why Estimates?

Intuit does not currently provide an API for creating **Delayed Charges** in QuickBooks Online.

Because of this limitation, the plugin generates an **Estimate** when an issue is closed. This estimate can later be converted into an invoice within QuickBooks.

The alternative approach would be to modify an invoice directly after it is associated with an issue, which introduces additional complexity and potential synchronization issues.

---

## Installation

1.  **Clone the plugin**
    

Navigate to your Redmine plugins directory:

```bash
cd /path/to/redmine/plugins  
git clone https://github.com/rickbarrette/redmine_qbo_lineitems.git  
cd redmine_qbo_lineitems  
  
# Optional: checkout a specific version  
git checkout <tag>
```


2.  **Install dependencies**
    
```bash
bundle install
```

3.  **Migrate your database**
    
```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

4.  **Restart Redmine**
    

Restart your application server (Puma, Passenger, etc.) to initialize the plugin hooks.

---

## Configuration

This plugin depends on the **Redmine QuickBooks Online** plugin.

Before using this plugin:

1.  Install and configure the parent plugin.
    
2.  Ensure your **QuickBooks Online** company file is connected.
    
3.  Verify that the products or services referenced in line items exist in QuickBooks.
    

---

## Usage

1.  **Configure:** Ensure the parent QuickBooks Online plugin is connected to your company file.
    
2.  **Add Items:** On the issue page, use the new **Line Items** section to add billable products or services.
    
3.  **Generate Estimate:** When the work is complete, change the issue status to a state marked as **closed** in Redmine. The plugin will then trigger the creation of a new estimate in **QuickBooks Online**.
    

---

## License

> The MIT License (MIT)
> 
> Copyright (c) 2026 Rick Barrette
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.