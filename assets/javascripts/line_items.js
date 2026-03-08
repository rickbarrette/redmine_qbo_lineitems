function updateLineItemTotals() {
  let grandTotal = 0;

  document.querySelectorAll(".line-item").forEach(function(row){
    
    // 1. Look for the Rails _destroy hidden field
    let destroyInput = row.querySelector("input[name*='[_destroy]']");
    let isDestroyed = destroyInput && (destroyInput.value === "1" || destroyInput.value === "true");
    
    // 2. Safely check if the row is hidden via CSS, without relying on physical layout
    let isHidden = row.style.display === "none" || window.getComputedStyle(row).display === "none";

    // If it's deleted or explicitly hidden, skip calculating it
    if (isDestroyed || isHidden) {
      return; 
    }

    let qty = parseFloat(row.querySelector(".qty-field")?.value || 0);
    let price = parseFloat(row.querySelector(".price-field")?.value || 0);

    let total = qty * price;

    row.querySelector(".line-total").textContent =
      total.toLocaleString(undefined,{minimumFractionDigits:2,maximumFractionDigits:2});

    grandTotal += total;

  });

  let grand = document.getElementById("line-items-grand-total");

  if(grand){
    grand.textContent =
      grandTotal.toLocaleString(undefined,{minimumFractionDigits:2,maximumFractionDigits:2});
  }
}

// Recalculate on input changes
document.addEventListener("input", function(e){
  if(e.target.classList.contains("qty-field") ||
     e.target.classList.contains("price-field")){
    updateLineItemTotals();
  }
});

// Recalculate when the remove button is clicked
document.addEventListener("click", function(e){
  let removeBtn = e.target.closest("[data-nested-form-remove]");
  
  if(removeBtn){
    setTimeout(updateLineItemTotals, 10);
  }
});

// Initial calculation on load
document.addEventListener("DOMContentLoaded", function(){
  updateLineItemTotals();
});