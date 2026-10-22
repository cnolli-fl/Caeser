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
        new PropertyMetadata(DownloadSource.Video, (d, _) => ((SourceSelector)d).SourceChanged()));
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
    private bool transferringCapture;
    private bool updatingButtons;
    private readonly UISettings settings = new();
    internal bool? MotionEnabledOverride { get; set; }
    internal int PointerPressCount { get; private set; }
    internal string PointerDiagnostics { get; private set; } = "";
    private void TracePointer(string value)
    {
        if (MotionEnabledOverride == null) return;
        PointerDiagnostics += value + "; ";
        if (PointerDiagnostics.Length > 2000) PointerDiagnostics = PointerDiagnostics[^2000..];
    }

    public SourceSelector()
    {
        InitializeComponent();
        AddHandler(PointerPressedEvent, new PointerEventHandler(OnPressed), true);
        AddHandler(PointerMovedEvent, new PointerEventHandler(OnMoved), true);
        AddHandler(PointerReleasedEvent, new PointerEventHandler(OnReleased), true);
        PointerCanceled += (_, e) =>
        {
            TracePointer($"canceled {e.OriginalSource?.GetType().Name}, transfer={transferringCapture}");
            if (!transferringCapture && ReferenceEquals(e.OriginalSource, this)) ResetDrag();
        };
        // Taking capture away from a child also bubbles this event. Only losing
        // our own capture cancels a drag; otherwise the first move resets it.
        PointerCaptureLost += (_, e) =>
        {
            TracePointer($"capture lost {e.OriginalSource?.GetType().Name}, transfer={transferringCapture}");
            if (!transferringCapture && ReferenceEquals(e.OriginalSource, this)) ResetDrag();
        };
        Loaded += (_, _) => UpdateSelection(false);
        Unloaded += (_, _) => StopAnimation();
        IsEnabledChanged += (_, _) => { if (!IsEnabled) ResetDrag(); };
    }
    private void SourceChanged()
    {
        UpdateSelection(true);
        // Layout, button synchronization and selecting an already selected item
        // must never emit another model change inside the checked event.
        SelectionChanged?.Invoke(this, EventArgs.Empty);
    }
    private void UpdateSelection(bool animate)
    {
        if (YouTubeButton == null) return;
        updatingButtons = true;
        try
        {
            YouTubeButton.IsChecked = SelectedSource == DownloadSource.Video;
            SpotifyButton.IsChecked = SelectedSource == DownloadSource.Spotify;
        }
        finally { updatingButtons = false; }
        Thumb.Width = Math.Max(0, Inner.ActualWidth / 2);
        MoveTo(SelectedSource == DownloadSource.Video ? 0 : Inner.ActualWidth / 2, animate);
    }
    private void Select(DownloadSource source)
    {
        if (SelectedSource == source) UpdateSelection(true);
        else SelectedSource = source;
    }
    private void StopAnimation()
    {
        var current = ThumbTranslation.X;
        var previous = animation;
        animation = null;
        previous?.Stop();
        ThumbTranslation.X = current;
    }
    private void MoveTo(double target, bool animate)
    {
        var current = ThumbTranslation.X;
        StopAnimation();
        if (!animate || !(MotionEnabledOverride ?? settings.AnimationsEnabled) || !IsLoaded || Math.Abs(current - target) < 0.1)
        { ThumbTranslation.X = target; return; }
        var next = new Storyboard();
        var move = new DoubleAnimation
        {
            From = current, To = target, Duration = TimeSpan.FromMilliseconds(280),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };
        Storyboard.SetTarget(move, Thumb);
        Storyboard.SetTargetProperty(move, "(UIElement.RenderTransform).(TranslateTransform.X)");
        next.Children.Add(move);
        next.Completed += (_, _) =>
        {
            if (animation != next) return;
            animation = null; next.Stop(); ThumbTranslation.X = target;
        };
        // Keep the base value correct even when Windows skips or disables an
        // animation. The explicit From value still starts at the visible point.
        ThumbTranslation.X = target;
        animation = next; next.Begin();
    }
    private void YouTube_Checked(object sender, RoutedEventArgs e)
    {
        if (updatingButtons) return;
        Select(DownloadSource.Video);
    }
    private void Spotify_Checked(object sender, RoutedEventArgs e)
    {
        if (updatingButtons) return;
        Select(DownloadSource.Spotify);
    }
    private void Track_SizeChanged(object sender, SizeChangedEventArgs e)
    { if (Math.Abs(e.NewSize.Width - e.PreviousSize.Width) > 0.1) UpdateSelection(false); }
    private void Track_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (!IsEnabled) return;
        if (e.Key is VirtualKey.Left or VirtualKey.Home) Select(DownloadSource.Video);
        else if (e.Key is VirtualKey.Right or VirtualKey.End) Select(DownloadSource.Spotify);
        else return;
        (SelectedSource == DownloadSource.Video ? YouTubeButton : SpotifyButton).Focus(FocusState.Keyboard);
        e.Handled = true;
    }
    private void OnPressed(object sender, PointerRoutedEventArgs e)
    {
        PointerPressCount++;
        if (!IsEnabled || !e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) return;
        pressed = e.GetCurrentPoint(this).Position;
        TracePointer($"press {pressed}");
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
            transferringCapture = true;
            try { dragging = CapturePointer(e.Pointer); }
            finally { transferringCapture = false; }
            TracePointer($"capture={dragging}, pressed={pressed}");
        }
        if (!dragging) return;
        MoveTo(Math.Clamp(initial + dx, 0, Inner.ActualWidth / 2), false);
        e.Handled = true;
    }
    private void OnReleased(object sender, PointerRoutedEventArgs e)
    {
        if (!dragging) { pressed = null; return; }
        var target = ThumbTranslation.X >= Inner.ActualWidth / 4 ? DownloadSource.Spotify : DownloadSource.Video;
        TracePointer($"release x={ThumbTranslation.X}, target={target}");
        dragging = false; pressed = null;
        ReleasePointerCapture(e.Pointer);
        Select(target); e.Handled = true;
    }
    private void ResetDrag()
    {
        if (pressed == null && !dragging) return;
        TracePointer("reset");
        pressed = null; dragging = false; UpdateSelection(true);
    }
}
