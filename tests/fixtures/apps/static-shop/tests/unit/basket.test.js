import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBasket } from '../../site/basket.js';

test('count reflects the products added', () => {
  const basket = createBasket();
  basket.add('tea-towel');
  basket.add('mug');
  assert.equal(basket.count(), 2);
});
