let lastKeyWasTab = false;

document.addEventListener("keydown", function (e) {
  lastKeyWasTab = (e.key === "Tab");
});

(function () {
  function initNestedForms() {
    document.querySelectorAll("[data-nested-form]").forEach(function (wrapper) {
      if (wrapper.dataset.initialized === "true") return;
      wrapper.dataset.initialized = "true";

      const container = wrapper.querySelector("[data-nested-form-container]");
      const template = wrapper.querySelector("[data-nested-form-template]");

      if (!container || !template) return;

      wrapper.addEventListener("click", function (event) {
        const addButton = event.target.closest("[data-nested-form-add]");
        const removeButton = event.target.closest("[data-nested-form-remove]");

        // ADD
        if (addButton) {
          event.preventDefault();

          const content = template.innerHTML.replace(
            /NEW_RECORD/g,
            Date.now().toString()
          );

          container.insertAdjacentHTML("beforeend", content);

          const newRow = container.lastElementChild;

          // Ensure clean state
          newRow.dataset.autoAdded = "false";

          // Reset defaults
          const qty = newRow.querySelector(".qty-field");
          if (qty && !qty.value) qty.value = 1;

          const price = newRow.querySelector(".price-field");
          if (price) price.value = "";

          // initialize autocomplete
          initLineItemAutocomplete(newRow);

          // Only focus if NOT tabbing
          if (!lastKeyWasTab) {
            const desc = newRow.querySelector(".line-item-description");
            if (desc) desc.focus();
          }
        }

        // REMOVE
        if (removeButton) {
          event.preventDefault();

          const lineItem = removeButton.closest(wrapper.dataset.wrapperSelector);
          if (!lineItem) return;

          const destroyField = lineItem.querySelector("input[name*='_destroy']");

          if (destroyField) {
            destroyField.value = "1";
            lineItem.style.display = "none";
          } else {
            lineItem.remove();
          }
        }
      });
    });
  }

  // Works for full load
  document.addEventListener("DOMContentLoaded", initNestedForms);

  // Works for Turbo navigation
  document.addEventListener("turbo:load", initNestedForms);
})();


// Keep your existing behavior
$(document).on("input", ".line-item-description", function () {
  let row = $(this).closest(".line-item");
  row.find(".item-id-field").val("");
});


// -------------------------------
// AUTO-ADD NEW ROW LOGIC
// -------------------------------

// Reset autoAdded flag if cleared
document.addEventListener("input", function (e) {
  if (!e.target.classList.contains("line-item-description")) return;

  const row = e.target.closest(".line-item");
  if (!row) return;

  if (e.target.value.trim() === "") {
    row.dataset.autoAdded = "false";
  }
});


// Add row when leaving last description (without breaking TAB flow)
document.addEventListener("blur", function (e) {
  if (!e.target.classList.contains("line-item-description")) return;

  const input = e.target;
  const row = input.closest(".line-item");
  if (!row) return;

  const wrapper = input.closest("[data-nested-form]");
  if (!wrapper) return;

  const container = wrapper.querySelector("[data-nested-form-container]");
  if (!container) return;

  // Active (visible + not destroyed) rows only
  const rows = Array.from(
    container.querySelectorAll(wrapper.dataset.wrapperSelector)
  ).filter(r => {
    const destroy = r.querySelector("input[name*='[_destroy]']");
    const hidden = window.getComputedStyle(r).display === "none";
    return !(destroy && destroy.value === "1") && !hidden;
  });

  const lastRow = rows[rows.length - 1];

  // Only last row
  if (row !== lastRow) return;

  // Must have content
  if (input.value.trim() === "") return;

  // Prevent duplicate firing
  if (row.dataset.autoAdded === "true") return;

  // If TAB, ensure user is leaving the row entirely
  if (lastKeyWasTab) {
    const next = document.activeElement;

    if (row.contains(next)) {
      return; // still inside row → allow normal tabbing
    }
  }

  row.dataset.autoAdded = "true";

  const addButton = wrapper.querySelector("[data-nested-form-add]");
  if (addButton) addButton.click();

}, true); // capture phase required for blur