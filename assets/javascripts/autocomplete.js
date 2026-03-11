(function () {

  window.initLineItemAutocomplete = function(context) {
    let scope = context || document;

    $(scope).find(".line-item-description").each(function() {
      if ($(this).data("autocomplete-initialized")) return;
      $(this).data("autocomplete-initialized", true);

      let ac = $(this).autocomplete({
        appendTo: "body",
        minLength: 2,

        source: function(request, response) {
          $.getJSON("/items/autocomplete", { q: request.term })
            .done(function(data) {

              response(data.map(function(item) {
                return {
                  label: item.description,
                  value: item.description,
                  id: item.id,
                  name: item.name,
                  sku: item.sku,
                  description: item.description,
                  price: item.price || 0
                };
              }));

            })
            .fail(function(err){
              console.error("Autocomplete error:", err);
              response([]);
            });
        },

        select: function(event, ui) {
          let $input = $(this);
          let row = $input.closest(".line-item");

          // set description into input
          $input.val(ui.item.description);

          row.find(".item-id-field").val(ui.item.id);

          if (ui.item.price !== undefined && row.find(".price-field").length) {
            row.find(".price-field").val(ui.item.price);
          }

          updateLineItemTotals();

          return false;
        },

        change: function(event, ui) {
          if (!ui.item) {
            let row = $(this).closest(".line-item");
            row.find(".item-id-field").val("");
          }
        }

      });

      // Custom rendering of autocomplete suggestions
      ac.autocomplete("instance")._renderItem = function(ul, item) {
        return $("<li>")
          .append(
            "<div class='autocomplete-item'>" +
              "<div class='item-name'>" + item.name + "</div>" +
              "<div class='item-sku'>" + item.sku + "</div>" +
              "<div class='item-description'>" + item.description + "</div>" +
            "</div>"
          )
          .appendTo(ul);
      };

    });
  };

  // Clear item_id when user types manually
  $(document).on("input", ".line-item-description", function(){
    let row = $(this).closest(".line-item");
    row.find(".item-id-field").val("");
  });

  function initializeAutocomplete() {
    window.initLineItemAutocomplete(document);
  }

  $(document).ready(initializeAutocomplete);
  document.addEventListener("turbo:load", initializeAutocomplete);

})();