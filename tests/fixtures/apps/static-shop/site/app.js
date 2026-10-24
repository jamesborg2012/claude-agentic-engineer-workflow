import { createBasket } from './basket.js';

const basket = createBasket();
const countElement = document.getElementById('basket-count');

for (const button of document.querySelectorAll('[data-product-id]')) {
  button.addEventListener('click', () => {
    basket.add(button.dataset.productId);
    countElement.dataset.count = String(basket.count());
  });
}
