using Caeser.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media.Animation;
using Windows.Foundation;
using Windows.System;
using Windows.UI.ViewManagement;

namespace Caeser.App.Controls;

public sealed partial class SourceSelector : UserControl
{
    public static readonly DependencyProperty SelectedSourceProperty = DependencyProperty.Register(
        nameof(SelectedSource), typeof(DownloadSource), typeof(SourceSelector),
        new PropertyMetadata(DownloadSource.Video, (d, _) => ((SourceSelector)d).UpdateSelection(true)));
    public DownloadSource SelectedSource
    {
        get => (DownloadSource)GetValue(SelectedSourceProperty);
        set => SetValue(SelectedSourceProperty, value);
    }
    public event EventHandler? SelectionChanged;
    private Storyboard? animation;
    private Point? pressed;
    private double initial;
    private bool dragging;
    private readonly UISettings settings = new();

    public SourceSelector()
    {
        InitializeComponent();
        AddHandler(PointerPressedEvent, new PointerEventHandler(OnPressed), true);
        AddHandler(PointerMovedEvent, new PointerEventHandler(OnMoved), true);
        AddHandler(PointerReleasedEvent, new PointerEventHandler(OnReleased), true);
        PointerCanceled += (_, _) => ResetDrag();
        PointerCaptureLost += (_, _) => ResetDrag();
        Loaded += (_, _) => UpdateSelection(false);
        IsEnabledChanged += (_, _) => { if (!IsEnabled) ResetDrag(); };
    }
    private void UpdateSelection(bool animate)
    {
        if (YouTubeButton == null) return;
        YouTubeButton.IsChecked = SelectedSource == DownloadSource.Video;
        SpotifyButton.IsChecked = SelectedSource == DownloadSource.Spotify;
        Thumb.Width = Math.Max(0, Inner.ActualWidth / 2);
        MoveTo(SelectedSource == DownloadSource.Video ? 0 : Inner.ActualWidth / 2, animate);
        SelectionChanged?.Invoke(this, EventArgs.Empty);
    }
    private void MoveTo(double target, bool animate)
    {
        var current = ThumbTranslation.X;
        animation?.Stop(); animation = null;
        ThumbTranslation.X = current;
        if (!animate || !settings.AnimationsEnabled || !IsLoaded)
        { ThumbTranslation.X = target; return; }
        var next = new Storyboard();
        var move = new DoubleAnimation
        {
            From = current, To = target, Duration = TimeSpan.FromMilliseconds(280),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };
        Storyboard.SetTarget(move, ThumbTranslation);
        Storyboard.SetTargetProperty(move, "X");
        next.Children.Add(move);
        next.Completed += (_, _) =>
        {
            if (animation != next) return;
            next.Stop(); ThumbTranslation.X = target; animation = null;
        };
        animation = next; next.Begin();
    }
    private void YouTube_Click(object sender, RoutedEventArgs e)
    { SelectedSource = DownloadSource.Video; UpdateSelection(true); }
    private void Spotify_Click(object sender, RoutedEventArgs e)
    { SelectedSource = DownloadSource.Spotify; UpdateSelection(true); }
    private void Track_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateSelection(false);
    private void Track_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (!IsEnabled) return;
        if (e.Key is VirtualKey.Left or VirtualKey.Home) SelectedSource = DownloadSource.Video;
        else if (e.Key is VirtualKey.Right or VirtualKey.End) SelectedSource = DownloadSource.Spotify;
        else return;
        UpdateSelection(true);
        (SelectedSource == DownloadSource.Video ? YouTubeButton : SpotifyButton).Focus(FocusState.Keyboard);
        e.Handled = true;
    }
    private void OnPressed(object sender, PointerRoutedEventArgs e)
    {
        if (!IsEnabled || !e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) return;
        pressed = e.GetCurrentPoint(this).Position;
        initial = SelectedSource == DownloadSource.Video ? 0 : Inner.ActualWidth / 2;
    }
    private void OnMoved(object sender, PointerRoutedEventArgs e)
    {
        if (pressed == null || !IsEnabled) return;
        var point = e.GetCurrentPoint(this).Position;
        var dx = point.X - pressed.Value.X;
        if (!dragging)
        {
            if (Math.Abs(dx) < 5 || Math.Abs(dx) < Math.Abs(point.Y - pressed.Value.Y)) return;
            dragging = CapturePointer(e.Pointer);
        }
        if (!dragging) return;
        MoveTo(Math.Clamp(initial + dx, 0, Inner.ActualWidth / 2), false);
        e.Handled = true;
    }
    private void OnReleased(object sender, PointerRoutedEventArgs e)
    {
        if (!dragging) { pressed = null; return; }
        var target = ThumbTranslation.X >= Inner.ActualWidth / 4 ? DownloadSource.Spotify : DownloadSource.Video;
        dragging = false; pressed = null;
        ReleasePointerCapture(e.Pointer);
        SelectedSource = target; UpdateSelection(true); e.Handled = true;
    }
    private void ResetDrag()
    {
        if (pressed == null && !dragging) return;
        pressed = null; dragging = false; UpdateSelection(true);
    }
}
