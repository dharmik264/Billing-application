from django.db import models


class Category(models.Model):
    shop       = models.ForeignKey('shop.Shop', on_delete=models.CASCADE, related_name='categories', null=True)
    name       = models.CharField(max_length=100)
    icon       = models.CharField(max_length=50, blank=True)   # emoji or icon name
    sort_order = models.PositiveIntegerField(default=0)
    is_active  = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering    = ['sort_order', 'name']
        verbose_name_plural = 'Categories'
        unique_together = ['shop', 'name']

    def __str__(self):
        return self.name


class MenuItem(models.Model):
    ITEM_TYPE_CHOICES = [
        ('veg',     'Vegetarian'),
        ('non_veg', 'Non-Vegetarian'),
        ('egg',     'Egg'),
    ]

    shop        = models.ForeignKey('shop.Shop', on_delete=models.CASCADE, related_name='menu_items', null=True)
    category    = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='items')
    name        = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    price       = models.DecimalField(max_digits=10, decimal_places=2)
    item_type   = models.CharField(max_length=10, choices=ITEM_TYPE_CHOICES, default='veg')
    image       = models.ImageField(upload_to='menu/items/', null=True, blank=True)
    is_available = models.BooleanField(default=True)
    is_featured  = models.BooleanField(default=False)
    sort_order   = models.PositiveIntegerField(default=0)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['sort_order', 'name']

    def __str__(self):
        return f"{self.name} - ₹{self.price}"
