{* $Id$ *}
{$content}
<table style="width: 100%; margin-top: 20px;">
    <tr>
        <th align="left">{$lang.order}</th>
        <th align="left">{$lang.date}</th>
        <th align="left">{$lang.status}</th>
    </tr>
    <tr>
        <td>{$order_info.order_id}</td>
        <td>{$order_info.timestamp|date_format:"%y-%m-%d %H:%M:%S"}</td>
        <td>
            {include file="common_templates/status.tpl" status=$order_info.status display="view" name="update_order[status]"}
            {if $order_info.status eq $status_pending}
            <a href="#"
               class="mtpayment-submit"
               data-order="{$order_info.order_id}"
               data-language="{$language}"
               data-customer-email="{$email}"
               data-amount="{$price}"
               data-currency="{$currency}"
               data-transaction="{$transaction}"
            >
                {$lang.checkout}
            </a>
            {/if}
        </td>
    </tr>
</table>

<script>
    var MTPAYMENT_INIT = {$init};
    var MTPAYMENT_USERNAME = '{$username}';
    var MTPAYMENT_OVERRIDE_CALLBACK_URL = {$override_callback_url};
    var MTPAYMENT_CALLBACK_URL = '{$callback_url}';
</script>
{literal}
<script>
    MTPayment = {
        isOpen: false,
        success: false,
        order: null,
        isOfflinePayment: false,
        transaction: null,
        customerEmail: null,
        amount: null,
        currency: null,
        language: null,
        init: function () {
            mrTangoCollect.set.recipient(MTPAYMENT_USERNAME);

            mrTangoCollect.onOpened = MTPayment.onOpen;
            mrTangoCollect.onClosed = MTPayment.onClose;

            mrTangoCollect.onSuccess = MTPayment.onSuccess;
            mrTangoCollect.onOffLinePayment = MTPayment.onOfflinePayment;

            MTPayment.initButtonPay();
        },
        initButtonPay: function () {
            $(document).delegate('.mtpayment-submit', 'click', function (e) {
                if (e.isDefaultPrevented()) {
                    return;
                }

                if (typeof $(this).data('ws-id') != 'undefined') {
                    mrTangoCollect.ws_id = $(this).data('websocket');
                }

                MTPayment.order = null;

                if (typeof $(this).data('order') != 'undefined') {
                    MTPayment.order = $(this).data('order');
                }

                MTPayment.transaction = $(this).data('transaction');
                MTPayment.customerEmail = $(this).data('customer-email');
                MTPayment.amount = $(this).data('amount');
                MTPayment.currency = $(this).data('currency');
                MTPayment.language = $(this).data('language');

                mrTangoCollect.set.payer(MTPayment.customerEmail);
                mrTangoCollect.set.amount(MTPayment.amount);
                mrTangoCollect.set.currency(MTPayment.currency);
                mrTangoCollect.set.description(MTPayment.transaction);
                mrTangoCollect.set.lang(MTPayment.language);

                if (MTPAYMENT_OVERRIDE_CALLBACK_URL) {
                    mrTangoCollect.custom = {'callback': MTPAYMENT_CALLBACK_URL};
                }

                MTPayment.isOpen = true;
                mrTangoCollect.submit();

                return false;
            });

            if (MTPAYMENT_INIT) {
                $(document).find('.mtpayment-submit').eq(0).trigger('click');
            }
        },
        onOpen: function () {
            MTPayment.isOpen = true;
        },
        onOfflinePayment: function (response) {
            mrTangoCollect.onSuccess = function () {
            };
            MTPayment.isOfflinePayment = true;
            MTPayment.onSuccess(response);
        },
        onSuccess: function (response) {
            MTPayment.success = true;

            if (MTPayment.isOpened === false) {
                MTPayment.afterSuccess();
            }
        },
        onClose: function () {
            MTPayment.isOpen = false;

            if (MTPayment.success) {
                MTPayment.afterSuccess();
            }
        },
        afterSuccess: function () {
            if (MTPAYMENT_INIT) {
                window.location.href = '/index.php?dispatch=checkout.complete&order_id=' + MTPayment.order;

                return;
            }

            window.location.href = '/index.php?dispatch=mtpayment.information&order=' + MTPayment.order;
        }
    };


    $.getScript("https://payment.mistertango.com/resources/scripts/mt.collect.js?v={/literal}{$smarty.now|escape:'htmlall':'UTF-8'}{literal}", function (data, textStatus, jqxhr) {
        MTPayment.init();
    });
</script>
{/literal}
