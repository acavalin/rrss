(function ($) { $(function () {
// -----------------------------------------------------------------------------
var arrow_scroll_pixels = 50; // pixels to scroll in linear mode

// divisione in pannelli
$.split_panels('div.panel.feeds', 'div.panel.feed', 'h', $.config.split_panels_h);
$.split_panels('div.panel.items', 'div.panel.item', 'v', $.config.split_panels_v);

$(document).ajaxComplete(function (ev) {
  $('.jqbt').button(); // stile bottoni
});

// shortcuts per la gestione degli items
$(document).keydown(function (ev) {
  if (ev.ctrlKey || ev.altKey || $(document.activeElement).is(':input'))
    return true;
  
  if ($.inArray(ev.which, [72, 78, 40, 36, 35, 77, 38, 85, 75, 27, 86, 82, 76, 82, 83, 13]) != -1)
    ev.preventDefault();
  
  var item = $('#items div.item.selected:visible:first');
  
  // console.log([ ev.which, ev.ctrlKey, ev.shiftKey, ev.altKey, item ]);
  
  if (ev.which == 72) {                             // h - help
    $.feeds.show_help();
  } else if (ev.which == 78) {                      // n - next unread
    item = item.length == 0 ?
      $('#items div.item.unread:visible:first') :     // prendi il primo
      item.nextAll('div.item.unread:visible:first');  // prendi il succ
    item.click().scroll_items_here();
  } else if (ev.which == 40) {                      // down - next
    if ($('#item .linear_item').length > 0) // scroll linear mode
      $('#item').scrollTop( $('#item').scrollTop() + arrow_scroll_pixels);
    else {
      item = item.length == 0 ?
        $('#items div.item:not(.toolbar):visible:first') :
        item.nextAll(':visible:first');
      item.click().scroll_items_here();
    }//if-else
  } else if (ev.which == 36) {                      // HOME - first
    item = $('#items div.item:not(.toolbar):visible:first');
    item.click().scroll_items_here();
  } else if (ev.which == 35) {                      // FINE - last
    item = $('#items div.item:not(arrows .toolbar):visible:last');
    item.click().scroll_items_here();
  } else if (ev.which == 77 || ev.which == 38) {    // m|up - prev
    if (ev.which == 38 && $('#item .linear_item').length > 0) // scroll linear mode
      $('#item').scrollTop( $('#item').scrollTop() - arrow_scroll_pixels);
    else {
      item = item.prevAll(':not(.toolbar):visible:first');
      item.click().scroll_items_here();
    }//if-else
  } else if (item.length != 0 && ev.which == 85) {  // u - toggle unread
    $.items.toggle_read(item);
  } else if (item.length != 0 && ev.which == 75) {  // k - toggle kept
    $.items.toggle_kept(item);
  } else if (ev.which == 27) {                      // ESC - close view
    $.items.close_view();
    $.feeds.refresh_feeds();
  } else if (ev.which == 86) {                      // v - change view
    $.items.next_filter();
  } else if (ev.which == 82) {                      // r - refresh | R - mark all read
    ev.shiftKey ?
      $.items.mark_all_read() :
      $.feeds.refresh_feeds();
  } else if (ev.which == 76) {                      // l/L - linear view (thumb/normal)
    $.items.linear_view(ev.shiftKey);
  } else if (ev.which == 83) {                      // s - search
    var feed_item = $('#feeds .selected');
    if (feed_item.length != 0) {
      var search_string = prompt('Type a search string');
      if (search_string)
        $.feeds.load_items(feed_item, { search: search_string, filter: 3 /*all*/ });
    }//if
  } else if (ev.which == 13) {                      // ENTER - open current item link
    var link = $('#item > div.root a[target="_blank"]:first');
    if (link.length > 0)
      // $('body').data('forward_url').length > 0 ?
      //   $.utils.fw_url(link.attr('href')) :
        window.open(link.attr('href'), '_blank');
  }//if-else
});
// -----------------------------------------------------------------------------
}); })(jQuery);
