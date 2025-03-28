from django.urls import path
from .views import RegisterView, LoginView, VideoUploadView, VideoListView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('videos/', VideoListView.as_view(), name='video-list'),
    path('videos/upload/', VideoUploadView.as_view(), name='video-upload'),
]