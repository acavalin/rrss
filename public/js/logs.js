(function ($) { $(function () {
// -----------------------------------------------------------------------------
$.extend($, {
  logs: {
    purge: function () {
      if (confirm('Purge all logs?')) {
        var icon = $('#item .ui-icon-trash');
        
        $.ajax({
          url: '/logs/purge',
          type: 'GET',
          dataType: 'text',
          cache: false,
          beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
          success: function (resp) {
            icon.parent().before('<small>(purged)</small>');
            $.feeds.refresh_feeds();
          },//success
          complete: function () { icon.next().remove(); },
          error: function () { alert('Server error!'); }
        });
      }//if
    },//purge
  },//logs
});
// -----------------------------------------------------------------------------
}); })(jQuery);
