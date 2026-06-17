from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, Organisation, EmailVerificationToken, PasswordResetToken


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display   = ('email', 'get_full_name', 'role', 'organisation', 'is_verified', 'is_active')
    list_filter    = ('role', 'is_active', 'is_verified')
    search_fields  = ('email', 'first_name', 'last_name')
    ordering       = ('email',)
    fieldsets      = (
        (None, {'fields': ('email', 'password')}),
        ('Personal', {'fields': ('first_name', 'last_name', 'phone', 'avatar')}),
        ('Organisation', {'fields': ('organisation', 'role')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'is_verified', 'groups', 'user_permissions')}),
    )
    add_fieldsets  = (
        (None, {'classes': ('wide',), 'fields': ('email', 'first_name', 'last_name', 'password1', 'password2')}),
    )


@admin.register(Organisation)
class OrganisationAdmin(admin.ModelAdmin):
    list_display  = ('name', 'slug', 'country', 'created_at')
    search_fields = ('name', 'slug')


admin.site.register(EmailVerificationToken)
admin.site.register(PasswordResetToken)
