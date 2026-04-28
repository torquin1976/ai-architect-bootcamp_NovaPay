import http from 'k6/http';
import { check, sleep } from 'k6';

//export const options = {
//  vus: 10,          // virtual users
//  duration: '30s',  // test duration
//};

export const options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '30s', target: 100 },
    { duration: '30s', target: 200 },
    { duration: '30s', target: 400 },
  ],
};

export default function () {
  const payload = JSON.stringify({
    card: '4111111111111111',
    amount: 100,
    merchantId: 'm1',
    idempotencyKey: `key-${__VU}-${__ITER}`
  });

  const res = http.post('http://localhost:3000/auth', payload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(res, {
    'auth success': (r) => r.status === 200,
  });

  sleep(1);
}