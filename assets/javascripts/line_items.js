function updateLineItemTotals() {

  let grandTotal = 0;

  document.querySelectorAll(".line-item").forEach(function(row){

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

document.addEventListener("input", function(e){

  if(e.target.classList.contains("qty-field") ||
     e.target.classList.contains("price-field")){

    updateLineItemTotals();

  }

});

document.addEventListener("DOMContentLoaded", function(){
  updateLineItemTotals();
});