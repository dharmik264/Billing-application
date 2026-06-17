"""
subscriptions/stripe_service.py
Stripe integration helpers for subscriptions.
"""
import stripe
from django.conf import settings
from django.utils import timezone

stripe.api_key = settings.STRIPE_SECRET_KEY


def get_or_create_stripe_customer(organisation):
    if organisation.stripe_customer_id:
        return stripe.Customer.retrieve(organisation.stripe_customer_id)
    customer = stripe.Customer.create(
        name=organisation.name,
        metadata={'org_id': str(organisation.id)},
    )
    organisation.stripe_customer_id = customer.id
    organisation.save()
    return customer


def create_subscription(organisation, plan):
    from .models import Subscription
    customer = get_or_create_stripe_customer(organisation)
    stripe_sub = stripe.Subscription.create(
        customer=customer.id,
        items=[{'price': plan.stripe_price_id}],
        trial_period_days=plan.trial_days or None,
        expand=['latest_invoice.payment_intent'],
    )
    sub, _ = Subscription.objects.update_or_create(
        organisation=organisation,
        defaults={
            'plan':                 plan,
            'status':               stripe_sub.status,
            'stripe_sub_id':        stripe_sub.id,
            'current_period_start': timezone.datetime.fromtimestamp(stripe_sub.current_period_start, tz=timezone.utc),
            'current_period_end':   timezone.datetime.fromtimestamp(stripe_sub.current_period_end, tz=timezone.utc),
        }
    )
    return sub


def change_plan(subscription, new_plan, prorate=True):
    stripe_sub = stripe.Subscription.retrieve(subscription.stripe_sub_id)
    stripe.Subscription.modify(
        subscription.stripe_sub_id,
        items=[{'id': stripe_sub['items']['data'][0].id, 'price': new_plan.stripe_price_id}],
        proration_behavior='create_prorations' if prorate else 'none',
    )
    from .models import SubscriptionHistory
    SubscriptionHistory.objects.create(
        subscription=subscription,
        event='plan_changed',
        old_plan=subscription.plan,
        new_plan=new_plan,
    )
    subscription.plan = new_plan
    subscription.save()
    return subscription


def cancel_subscription(subscription):
    stripe.Subscription.modify(subscription.stripe_sub_id, cancel_at_period_end=True)
    subscription.cancel_at = subscription.current_period_end
    subscription.save()
    return subscription


def resume_subscription(subscription):
    stripe.Subscription.modify(subscription.stripe_sub_id, cancel_at_period_end=False)
    subscription.cancel_at = None
    subscription.save()
    return subscription
