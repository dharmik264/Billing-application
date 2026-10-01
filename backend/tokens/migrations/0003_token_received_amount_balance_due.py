from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('tokens', '0002_token_items_summary'),
    ]

    operations = [
        migrations.AddField(
            model_name='token',
            name='received_amount',
            field=models.DecimalField(
                decimal_places=2,
                default=0,
                help_text='Amount paid today for an UDHAR bill',
                max_digits=10,
            ),
        ),
        migrations.AddField(
            model_name='token',
            name='balance_due',
            field=models.DecimalField(
                decimal_places=2,
                default=0,
                help_text='Remaining balance for UDHAR bills',
                max_digits=10,
            ),
        ),
    ]
