const fs = require('fs');
const path = require('path');

// Klasörün yolu
const klasorYolu = './scripts/';

// Klasörü oku
fs.readdir(klasorYolu, (err, dosyalar) => {
  if (err) {
    console.error('Klasör okunamadı:', err);
    return;
  }

  // Dosyaları listele
  console.log('Klasördeki dosyalar:');
  dosyalar.forEach((dosya) => {
    console.log(dosya);
  });
});