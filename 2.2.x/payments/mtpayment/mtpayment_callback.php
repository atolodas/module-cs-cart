<?php

define('AREA', 'C');
define('AREA_NAME' ,'customer');
define('SKIP_SESSION_VALIDATION', true);

class MisterTangoOrderPlacementRoutinesException extends Exception {}

require dirname(dirname(__DIR__)).'/prepare.php';
require dirname(dirname(__DIR__)).'/init.php';

/**
 * @param $encoded_text
 * @param $key
 * @return string
 */
function mtpayment_hash_decrypt($encoded_text, $key)
{
    if (strlen($key) == 30)
        $key .= "\0\0";

    $encoded_text = trim($encoded_text);
    $ciphertext_dec = base64_decode($encoded_text);
    $iv_size = mcrypt_get_iv_size(MCRYPT_RIJNDAEL_128, MCRYPT_MODE_CBC);
    $iv_dec = substr($ciphertext_dec, 0, $iv_size);

    $ciphertext_dec = substr($ciphertext_dec, $iv_size);
    $sResult = @mcrypt_decrypt(MCRYPT_RIJNDAEL_128, $key, $ciphertext_dec, MCRYPT_MODE_CBC, $iv_dec);

    return trim($sResult);
}

function mtpayment_close_order($order_id, $response)
{
    $order_info = fn_get_order_info($order_id);

    if ($response['currency'] != $order_info['secondary_currency']) {
        throw new Exception('Error occurred: The currency does not match');
    }

    if (intval(number_format($response['amount'], 2, '', '')) < intval(number_format($order_info['total'], 2, '', ''))) {
        throw new Exception('Error occurred: Amount is lower than required');
    }

    if (!fn_check_payment_script('mtpayment.php', $order_id)) {
        throw new Exception('Error occurred: Payment script is invalid');
    }

    fn_finish_payment($order_id, $response, false);
    fn_order_placement_routines($order_id, false, true, 'save');
}

$hash = isset($_POST['hash'])?$_POST['hash']:(isset($_GET['hash'])?$_GET['hash']:null);

if (empty($hash)) {
    die('Error occurred: Empty hash');
}

$processor_id = db_get_field('SELECT processor_id FROM ?:payment_processors WHERE processor = \'MisterTango\'');
$payment_params = db_get_field('SELECT params FROM ?:payments WHERE processor_id = ?i LIMIT 1', $processor_id);

if (empty($payment_params)) {
    die('Error occurred: Could not retrieve processor params');
}

$processor_params = unserialize($payment_params);

if (!isset($processor_params['secret_key']) || empty($processor_params['secret_key'])) {
    die('Error occurred: Could not retrieve secret key');
}

$data = json_decode(mtpayment_hash_decrypt($hash, $processor_params['secret_key']));
$data->custom = isset($data->custom) ? json_decode($data->custom) : null;

if (empty($data->custom) || empty($data->custom->description)) {
    die('Error occurred: Custom description is empty');
}

$transaction = explode('_', $data->custom->description);

if (count($transaction) != 2) {
    die('Error occurred: Transaction code is incorrect');
}

$callback = db_get_row('SELECT * FROM ?:callbacks_mtpayment WHERE uuid = ?s', $data->callback_uuid);
if (empty($callback)) {
    try {
        $order_id = $transaction[0];

        mtpayment_close_order(
            $order_id,
            array(
                'currency' =>  $data->custom->data->currency,
                'amount' =>  $data->custom->data->amount,
                'order_status' => isset($processor_params['status_paid'])?$processor_params['status_paid']:'P',
            )
        );
    } catch (MisterTangoOrderPlacementRoutinesException $e) {
        $callback_data = array(
            'uuid' => $data->callback_uuid,
            'transaction_id' => $data->custom->description,
            'amount' => $data->custom->data->amount
        );

        db_query('INSERT INTO ?:callbacks_mtpayment ?e', $callback_data);
    } catch (Exception $e) {
        die('Error occurred: '.$e->getMessage());
    }
}

die('OK');
