# Redmine QuickBooks Line Items

A Redmine plugin to complement the [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) plugin.

The goal of this project is to allow attaching billable line items to an Issue. These items are used to automatically generate a QuickBooks Estimate when the issue is closed.

## Requirements

* **Redmine:** 6.1+
* **Ruby:** 3.2+
* **Parent Plugin:** [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) (must be installed and configured)

## Compatibility
| Plugin Version | Redmine Version | Ruby Version |
| :--- | :--- | :--- |
| 2026.3.2+ | 6.1.x | 3.2+ |

## Features

* **Billable Line Items:** Easily attach specific billable line items items to any Redmine issue.
* **Automated Estimate Creation:** Automatically generates a QuickBooks Online Estimate upon closing an issue, streamlining the billing workflow.

## Installation

1.  **Clone the plugin:**
    Navigate to your Redmine plugins directory:
    ```bash
    cd path/to/redmine/plugins
    git clone git@github.com:rickbarrette/z_redmine_qbo_lineitems.git
    cd z_redmine_qbo_lineitems
    # Optional: git checkout <tag> 
    ```

2.  **Install dependencies:**
    ```bash
    bundle install
    ```

3.  **Migrate your database:**
    ```bash
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    ```

4.  **Restart Redmine:**
    Restart your application server (Puma, Passenger, etc.) to initialize the plugin hooks.

## Usage

1. **Configure:** Ensure the parent QuickBooks Online plugin is connected to your company file.
2. **Add Items:** On the Issue page, use the new "Line Items" section to add billable products or services.
3. **Generate Estimate:** When the work is complete, change the issue status to a "Closed" state. The plugin will trigger the creation of a new Estimate in QuickBooks Online.

## License

> The MIT License (MIT)
>
> Copyright (c) 2016 - 2026 Rick Barrette
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.