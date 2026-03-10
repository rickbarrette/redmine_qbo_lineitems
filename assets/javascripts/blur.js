function evaluateMathExpression(expr) {
  if (!expr) return null;

  // allow only digits, decimal, operators, parentheses, spaces
  if (!/^[0-9+\-*/().\s]+$/.test(expr)) {
    return null;
  }

  try {
    return Function('"use strict"; return (' + expr + ')')();
  } catch {
    return null;
  }
}

document.addEventListener("blur", function(e) {

  if (!e.target.classList.contains("price-field")) return;

  const field = e.target;
  const value = field.value.trim();

  const result = evaluateMathExpression(value);

  if (result !== null && !isNaN(result)) {
    field.value = Number(result).toFixed(2);
  }

  if (typeof updateLineItemTotals === "function") {
    updateLineItemTotals();
  }

}, true);