<?php
$admin_ips = getenv('ADMIN_IPS');
if (!$admin_ips) {
    return [];
}
return array_map('trim', explode(',', $admin_ips));
